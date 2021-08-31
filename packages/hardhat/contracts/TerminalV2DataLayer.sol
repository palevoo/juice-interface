// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@paulrberg/contracts/math/PRBMath.sol";
import "@paulrberg/contracts/math/PRBMathUD60x18.sol";

import "./interfaces/IGovernable.sol";
import "./interfaces/ITerminalDataLayer.sol";
import "./interfaces/ITerminalV2DataLayer.sol";

import "./abstract/JuiceboxProject.sol";
import "./abstract/Operatable.sol";

import "./libraries/Operations.sol";
import "./libraries/Operations2.sol";
import "./libraries/FundingCycleMetadataResolver.sol";

/**
  @notice 
  This contract stiches together funding cycles and community tokens. It makes sure all activity is accounted for and correct. 

  @dev 
  Each project can only have one terminal registered at a time with the TerminalDirectory. This is how the outside world knows where to send money to when trying to pay a project.
  The project's currently set terminal is the only contract that can interact with the FundingCycles and TicketBooth contracts on behalf of the project.

  The project's currently set terminal is also the contract that will receive payments by default when the outside world references directly from the TerminalDirectory.
  Since this contract doesn't deal with money directly, it will immedeiately forward payments to appropriate functions in the payment layer if it receives external calls via ITerminal methods `pay` or `addToBalance`.
  
  Inherits from:

  ITerminalV2DataLayer - general interface for the methods in this contract that change the blockchain's state according to the Juicebox protocol's rules.
  ITerminalDataLayer - conforms to ITerminal, which allows projects to migrate to this contract from other ITerminals (like TerminalV1), and to facilitate a project's future migration decisions.
  Ownable - the owner of this contract can specify its payment layer contract, and add new ITerminals to an allow list that projects currently using this terminal can migrate to.
  Operatable - several functions in this contract can only be accessed by a project owner, or an address that has been preconfifigured to be an operator of the project.
  ReentrencyGuard - several function in this contract shouldn't be accessible recursively.
*/
contract TerminalV2DataLayer is
    ITerminalV2DataLayer,
    ITerminalDataLayer,
    Ownable,
    Operatable,
    ReentrancyGuard
{
    // A library that parses the packed funding cycle metadata into a more friendly format.
    using FundingCycleMetadataResolver for FundingCycle;

    // Modifier to only allow the payment layer to call the function.
    modifier onlyPaymentLayer() {
        require(msg.sender == address(paymentLayer), "TV2DL: UNAUTHORIZED");
        _;
    }
    // --- private stored properties --- //

    // The difference between the processed token tracker of a project and the project's token's total supply is the amount of tokens that
    // still need to have reserves minted against them.
    mapping(uint256 => int256) private _processedTokenTrackerOf;

    // The amount of tokens printed prior to a project configuring their first funding cycle and receiving a payment.
    mapping(uint256 => uint256) private _preconfigureTokenCountOf;

    // --- public immutable stored properties --- //

    /// @notice The Projects contract which mints ERC-721's that represent project ownership.
    IProjects public immutable override projects;

    /// @notice The contract storing all funding cycle configurations.
    IFundingCycles public immutable override fundingCycles;

    /// @notice The contract that manages token minting and burning.
    ITicketBooth public immutable override ticketBooth;

    /// @notice The contract that stores split modules for each project.
    IModStore public immutable override modStore;

    /// @notice The contract that exposes price feeds.
    IPrices public immutable override prices;

    /// @notice The directory of terminals.
    ITerminalDirectory public immutable override terminalDirectory;

    // --- public stored properties --- //

    /// @notice The amount of ETH that each project has.
    mapping(uint256 => uint256) public override balanceOf;

    // Whether or not a particular contract is available for projects to migrate their funds to.
    mapping(ITerminal => bool) public override migrationIsAllowed;

    // The amount of overflow that a project is allowed to tap into on-demand.
    mapping(uint256 => mapping(uint256 => uint256))
        public
        override overflowAllowanceOf;

    /// @notice The contract that stores funds, and manages inflows/outflows.
    ITerminalV2PaymentLayer public override paymentLayer;

    // --- external views --- //

    /**
      @notice
      Gets the current overflowed amount for a specified project.

      @param _projectId The ID of the project to get overflow for.

      @return The current amount of overflow that project has.
    */
    function currentOverflowOf(uint256 _projectId)
        external
        view
        override
        returns (uint256)
    {
        // Get a reference to the project's current funding cycle.
        FundingCycle memory _fundingCycle = fundingCycles.currentOf(_projectId);

        // There's no overflow if there's no funding cycle.
        if (_fundingCycle.number == 0) return 0;

        return _overflowFrom(_fundingCycle);
    }

    /**
      @notice
      Gets the amount of reserved tokens that a project has available to distribute.

      @param _projectId The ID of the project to get a reserved token balance of.
      @param _reservedRate The reserved rate to use when making the calculation.

      @return The current amount of reserved tokens.
    */
    function reservedTokenBalanceOf(uint256 _projectId, uint256 _reservedRate)
        external
        view
        override
        returns (uint256)
    {
        return
            _reservedTokenAmountFrom(
                _processedTokenTrackerOf[_projectId],
                _reservedRate,
                ticketBooth.totalSupplyOf(_projectId)
            );
    }

    /**
      @notice
      The amount of overflowed ETH that can be claimed by the specified number of tokens.

      @dev If the project has an active funding cycle reconfiguration ballot, the project's ballot redemption rate is used.

      @param _projectId The ID of the project to get a claimable amount for.
      @param _tokenCount The number of tokens to make the calculation with. 

      @return The amount of overflowed ETH that can be claimed.
    */
    function claimableOverflowOf(uint256 _projectId, uint256 _tokenCount)
        external
        view
        override
        returns (uint256)
    {
        return
            _claimableOverflowOf(
                fundingCycles.currentOf(_projectId),
                _tokenCount
            );
    }

    // --- public views --- //

    /**
      @notice
      Whether or not a project can still mint premined tokens.

      @param _projectId The ID of the project to get the status of.

      @return Boolean flag.
    */
    function canMintPreminedTokens(uint256 _projectId)
        public
        view
        override
        returns (bool)
    {
        return
            // The total supply of tokens must equal the preconfigured token count.
            ticketBooth.totalSupplyOf(_projectId) ==
            _preconfigureTokenCountOf[_projectId] &&
            // The above condition is still possible after post-configured tokens have been printed due to token redeeming.
            // The only case when the processedTokenTracker is 0 is before redeeming and before minting reserved tokens.
            _processedTokenTrackerOf[_projectId] >= 0 &&
            uint256(_processedTokenTrackerOf[_projectId]) ==
            _preconfigureTokenCountOf[_projectId];
    }

    // --- external transactions --- //

    /**
      @param _projects A Projects contract which mints ERC-721's that represent project ownership and transfers.
      @param _fundingCycles The contract storing all funding cycle configurations.
      @param _ticketBooth The contract that manages token minting and burning.
      @param _operatorStore A contract storing operator assignments.
      @param _modStore The contract that stores split modules for each project.
      @param _prices The contract that exposes price feeds.
      @param _terminalDirectory The directory of terminals.
    */
    constructor(
        IProjects _projects,
        IFundingCycles _fundingCycles,
        ITicketBooth _ticketBooth,
        IOperatorStore _operatorStore,
        IModStore _modStore,
        IPrices _prices,
        ITerminalDirectory _terminalDirectory
    ) Operatable(_operatorStore) {
        require(
            _projects != IProjects(address(0)) &&
                _fundingCycles != IFundingCycles(address(0)) &&
                _ticketBooth != ITicketBooth(address(0)) &&
                _modStore != IModStore(address(0)) &&
                _prices != IPrices(address(0)) &&
                _terminalDirectory != ITerminalDirectory(address(0)),
            "TV2DL: ZERO_ADDRESS"
        );
        projects = _projects;
        fundingCycles = _fundingCycles;
        ticketBooth = _ticketBooth;
        modStore = _modStore;
        prices = _prices;
        terminalDirectory = _terminalDirectory;
    }

    /**
      @notice
      Deploys a project. This will mint an ERC-721 into the `_owner`'s account, configure a first funding cycle, and set up any split modules.

      @dev
      Each operation withing this transaction can be done in sequence separately.

      @dev
      Anyone can deploy a project on an owner's behalf.

      @dev 
      A project owner will be able to reconfigure the funding cycle's properties as long as it has not yet received a payment.

      @param _owner The address that will own the project.
      @param _handle The project's unique handle. This can be updated any time by the owner of the project.
      @param _uri A link to associate with the project. This can be updated any time by the owner of the project.
      @param _properties The funding cycle configuration properties. These properties will remain fixed for the duration of the funding cycle.
        @dev _properties.target The amount that the project wants to payout during a funding cycle. Sent as a wad (18 decimals).
        @dev _properties.currency The currency of the `target`. Send 0 for ETH or 1 for USD.
        @dev _properties.duration The duration of the funding cycle for which the `target` amount is needed. Measured in days. Send 0 for cycles that are reconfigurable at any time.
        @dev _properties.cycleLimit The number of cycles that this configuration should last for before going back to the last permanent cycle. This has no effect for a project's first funding cycle.
        @dev _properties.discountRate A number from 0-200 (0-20%) indicating how many tokens will be minted as a result of a contribution made to this funding cycle compared to one made to the project's next funding cycle.
          If it's 0 (0%), each funding cycle's will have equal weight.
          If the number is 100 (10%), a contribution to the next funding cycle will only mint 90% of tokens that a contribution of the same amount made during the current funding cycle mints.
          If the number is 200 (20%), the difference will be 20%. 
          There's a special case: If the number is 201, the funding cycle will be non-recurring and one-time only.
        @dev _properties.ballot The ballot contract that will be used to approve subsequent reconfigurations. Must adhere to the IFundingCycleBallot interface.
      @param _metadata A struct specifying the TerminalV2 specific params _bondingCurveRate, and _reservedRate.
        @dev _metadata.reservedRate A number from 0-200 (0-100%) indicating the percentage of each contribution's newly minted tokens that will be reserved for the token split modules.
        @dev _metadata.redemptionRate The rate from 0-200 (0-100%) that tunes the bonding curve according to which a project's tokens can be redeemed for overflow.
          The bonding curve formula is https://www.desmos.com/calculator/sp9ru6zbpk
          where x is _count, o is _currentOverflow, s is _totalSupply, and r is _redemptionRate.
        @dev _metadata.ballotRedemptionRate The redemption rate to apply when there is an active ballot.
        @dev _metadata.pausePay Whether or not the pay functionality should be paused during this cycle.
        @dev _metadata.pauseTap Whether or not the tap functionality should be paused during this cycle.
        @dev _metadata.pauseRedeem Whether or not the redeem functionality should be paused during this cycle.
        @dev _metadata.useDataSourceForPay Whether or not the data source should be used when processing a payment.
        @dev _metadata.useDataSourceForRedeem Whether or not the data source should be used when processing a redemption.
        @dev _metadata.dataSource A contract that exposes data that can be used within pay and redeem transactions. Must adhere to IFundingCycleDataSource.
      @param _overflowAllowance The amount, in wei (18 decimals), of ETH that a project can use from its own overflow on-demand.
      @param _payoutMods Any payout split modules to set.
      @param _tokenMods Any token split modules to set.
    */
    function deploy(
        address _owner,
        bytes32 _handle,
        string calldata _uri,
        FundingCycleProperties calldata _properties,
        FundingCycleMetadataV2 calldata _metadata,
        uint256 _overflowAllowance,
        PayoutMod[] memory _payoutMods,
        TicketMod[] memory _tokenMods
    ) external override {
        // Make sure the metadata is validated and packed into a uint256.
        uint256 _packedMetadata = _validateAndPackFundingCycleMetadata(
            _metadata
        );

        // Create the project for the owner. This this contract as the project's terminal,
        // which will give it exclusive access to manage the project's funding cycles and tokens.
        uint256 _projectId = projects.create(_owner, _handle, _uri, this);

        // Configure the funding cycle's properties.
        FundingCycle memory _fundingCycle = fundingCycles.configure(
            _projectId,
            _properties,
            _packedMetadata,
            10, // Fee fixed at 5% (number is out of 200)
            true // configure the active funding cycle. This property shouldn't matter since the project shouldn't yet have a funding cycle.
        );

        // Set payout split modules if there are any.
        if (_payoutMods.length > 0)
            modStore.setPayoutMods(
                _projectId,
                _fundingCycle.configured,
                _payoutMods
            );

        // Set token split modules if there are any.
        if (_tokenMods.length > 0)
            modStore.setTicketMods(
                _projectId,
                _fundingCycle.configured,
                _tokenMods
            );

        // Set the overflow allowance if the value is different from the currently set value.
        if (
            _overflowAllowance !=
            overflowAllowanceOf[_projectId][_fundingCycle.configured]
        )
            _setOverflowAllowance(
                _projectId,
                _fundingCycle.configured,
                _overflowAllowance
            );
    }

    /**
      @notice
      Configures the properties of the current funding cycle if the project hasn't distributed tickets yet, or
      sets the properties of the proposed funding cycle that will take effect once the current one expires
      if it is approved by the current funding cycle's ballot.

      @dev
      Only a project's owner or a designated operator can configure its funding cycles.

      @param _projectId The ID of the project whos funding cycles are being reconfigured.
      @param _properties The funding cycle configuration properties. These properties will remain fixed for the duration of the funding cycle.
        @dev _properties.target The amount that the project wants to payout during a funding cycle. Sent as a wad (18 decimals).
        @dev _properties.currency The currency of the `target`. Send 0 for ETH or 1 for USD.
        @dev _properties.duration The duration of the funding cycle for which the `target` amount is needed. Measured in days. Send 0 for cycles that are reconfigurable at any time.
        @dev _properties.cycleLimit The number of cycles that this configuration should last for before going back to the last permanent cycle. This has no effect for a project's first funding cycle.
        @dev _properties.discountRate A number from 0-200 (0-20%) indicating how many tokens will be minted as a result of a contribution made to this funding cycle compared to one made to the project's next funding cycle.
          If it's 0 (0%), each funding cycle's will have equal weight.
          If the number is 100 (10%), a contribution to the next funding cycle will only mint 90% of tokens that a contribution of the same amount made during the current funding cycle mints.
          If the number is 200 (20%), the difference will be 20%. 
          There's a special case: If the number is 201, the funding cycle will be non-recurring and one-time only.
        @dev _properties.ballot The ballot contract that will be used to approve subsequent reconfigurations. Must adhere to the IFundingCycleBallot interface.
      @param _metadata A struct specifying the TerminalV2 specific params _bondingCurveRate, and _reservedRate.
        @dev _metadata.reservedRate A number from 0-200 (0-100%) indicating the percentage of each contribution's newly minted tokens that will be reserved for the token split modules.
        @dev _metadata.redemptionRate The rate from 0-200 (0-100%) that tunes the bonding curve according to which a project's tokens can be redeemed for overflow.
          The bonding curve formula is https://www.desmos.com/calculator/sp9ru6zbpk
          where x is _count, o is _currentOverflow, s is _totalSupply, and r is _redemptionRate.
        @dev _metadata.ballotRedemptionRate The redemption rate to apply when there is an active ballot.
        @dev _metadata.pausePay Whether or not the pay functionality should be paused during this cycle.
        @dev _metadata.pauseTap Whether or not the tap functionality should be paused during this cycle.
        @dev _metadata.pauseRedeem Whether or not the redeem functionality should be paused during this cycle.
        @dev _metadata.useDataSourceForPay Whether or not the data source should be used when processing a payment.
        @dev _metadata.useDataSourceForRedeem Whether or not the data source should be used when processing a redemption.
        @dev _metadata.dataSource A contract that exposes data that can be used within pay and redeem transactions. Must adhere to IFundingCycleDataSource.
      @param _overflowAllowance The amount, in wei (18 decimals), of ETH that a project can use from its own overflow on-demand.
      @param _payoutMods Any payout split modules to set.
      @param _tokenMods Any token split modules to set.

      @return The ID of the funding cycle that was successfully configured.
    */
    function configure(
        uint256 _projectId,
        FundingCycleProperties calldata _properties,
        FundingCycleMetadataV2 calldata _metadata,
        uint256 _overflowAllowance,
        PayoutMod[] memory _payoutMods,
        TicketMod[] memory _tokenMods
    )
        external
        override
        nonReentrant
        requirePermission(
            projects.ownerOf(_projectId),
            _projectId,
            Operations.Configure
        )
        returns (uint256)
    {
        // Make sure the metadata is validated and packed into a uint256.
        uint256 _packedMetadata = _validateAndPackFundingCycleMetadata(
            _metadata
        );

        // All reserved tokens must be minted before configuring.
        if (
            uint256(_processedTokenTrackerOf[_projectId]) !=
            ticketBooth.totalSupplyOf(_projectId)
        ) _mintReservedTokens(_projectId, "");

        // If the project can still mint premined tokens, configure the active funding cycle instead of queuing one for after the active one expires.
        bool _shouldConfigureActive = canMintPreminedTokens(_projectId);

        // Configure the funding cycle's properties.
        FundingCycle memory _fundingCycle = fundingCycles.configure(
            _projectId,
            _properties,
            _packedMetadata,
            10, // fee fixed at 10
            _shouldConfigureActive
        );

        // Set payout split modules if there are any.
        if (_payoutMods.length > 0)
            modStore.setPayoutMods(
                _projectId,
                _fundingCycle.configured,
                _payoutMods
            );

        // Set token split modules if there are any.
        if (_tokenMods.length > 0)
            modStore.setTicketMods(
                _projectId,
                _fundingCycle.configured,
                _tokenMods
            );

        // Set the overflow allowance if the value is different from the currently set value.
        if (
            _overflowAllowance !=
            overflowAllowanceOf[_projectId][_fundingCycle.configured]
        )
            _setOverflowAllowance(
                _projectId,
                _fundingCycle.configured,
                _overflowAllowance
            );

        return _fundingCycle.id;
    }

    /**
      HERE
      @notice
      Allows a project to print tokens for a specified beneficiary before payments have been received.

      @dev
      This can only be done if the project hasn't yet received a payment after configuring a funding cycle.

      @dev
      Only a project's owner or a designated operator can print premined tokens.

      @param _projectId The ID of the project to premine tokens for.
      @param _amount The amount to base the token premine off of.
      @param _currency The currency of the amount to base the token premine off of.
      @param _beneficiary The address to send the printed tokens to.
      @param _memo A memo to leave with the printing.
      @param _preferUnstakedTokens If there is a preference to unstake the printed tokens.
    */
    function mintPreminedTokens(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _weight,
        address _beneficiary,
        string memory _memo,
        bool _preferUnstakedTokens
    )
        external
        override
        nonReentrant
        requirePermission(
            projects.ownerOf(_projectId),
            _projectId,
            Operations.PrintPreminedTickets
        )
    {
        // Can't send to the zero address.
        require(
            _beneficiary != address(0),
            "TerminalV2::printPreminedTickets: ZERO_ADDRESS"
        );

        // Get the current funding cycle to read the weight and currency from.
        _weight = _weight > 0 ? _weight : fundingCycles.BASE_WEIGHT();

        // Get the current funding cycle to read the weight and currency from.
        // Multiply the amount by the funding cycle's weight to determine the amount of tokens to print.
        uint256 _weightedAmount = PRBMathUD60x18.mul(
            PRBMathUD60x18.div(_amount, prices.getETHPriceFor(_currency)),
            _weight
        );

        // Make sure the project hasnt printed tokens that werent preconfigure.
        // Do this check after the external calls above.
        require(
            canMintPreminedTokens(_projectId),
            "TerminalV2::canMintPreminedTokens: ALREADY_ACTIVE"
        );

        // Set the preconfigure tickets as processed so that reserved tickets cant be minted against them.
        _processedTokenTrackerOf[_projectId] =
            _processedTokenTrackerOf[_projectId] +
            int256(_weightedAmount);

        // Set the count of preconfigure tickets this project has printed.
        _preconfigureTokenCountOf[_projectId] =
            _preconfigureTokenCountOf[_projectId] +
            _weightedAmount;

        // Print the project's tickets for the beneficiary.
        ticketBooth.print(
            _beneficiary,
            _projectId,
            _weightedAmount,
            _preferUnstakedTokens
        );

        emit PrintPreminedTokens(
            _projectId,
            _beneficiary,
            _amount,
            _weight,
            _weightedAmount,
            _currency,
            _memo,
            msg.sender
        );
    }

    /**
      @notice
      Contribute ETH to a project.

      @dev
      Print's the project's tickets proportional to the amount of the contribution.

      @dev
      The msg.value is the amount of the contribution in wei.

      @param _projectId The ID of the project being contribute to.
      @param _beneficiary The address to print Tickets for.
      @param _memo A memo that will be included in the published event.
      @param _preferUnstakedTokens Whether ERC20's should be unstaked automatically if they have been issued.

      @return The ID of the funding cycle that the payment was made during.
    */
    function pay(
        uint256 _projectId,
        address _beneficiary,
        string calldata _memo,
        bool _preferUnstakedTokens
    ) external payable override returns (uint256) {
        require(msg.sender != address(paymentLayer), "TODO BAD");

        // This contract should not keep any ETH. It should relay it all
        // to the TerminalVault that owns this terminal.
        return
            paymentLayer.pay{value: msg.value}(
                _projectId,
                _beneficiary,
                0,
                _memo,
                _preferUnstakedTokens
            );
    }

    // /**
    //   @notice
    //   Contribute ETH to a project.

    //   @dev
    //   Print's the project's tickets proportional to the amount of the contribution.

    //   @dev
    //   The msg.value is the amount of the contribution in wei.

    //   @param _amount The amount that is being paid.
    //   @param _projectId The ID of the project being contribute to.
    //   @param _beneficiary The address to print Tickets for.
    //   @param _minReturnedTickets The minimum number of tickets expected in return.
    //   @param _memo A memo that will be included in the published event.
    //   @param _preferUnstakedTokens Whether ERC20's should be unstaked automatically if they have been issued.

    //   @return The ID of the funding cycle that the payment was made during.
    // */
    function pay(
        address _payer,
        uint256 _amount,
        uint256 _projectId,
        address _beneficiary,
        uint256 _minReturnedTokens,
        string memory _memo,
        bool _preferUnstakedTokens
    )
        public
        override
        onlyPaymentLayer
        returns (
            FundingCycle memory fundingCycle,
            uint256 weight,
            uint256 tokenCount,
            string memory memo
        )
    {
        // Get a reference to the current funding cycle for the project.
        fundingCycle = fundingCycles.currentOf(_projectId);

        // Must not be paused.
        require(!fundingCycle.payPaused(), "TerminalV2:_pay: PAUSED");

        require(fundingCycle.number > 0, "TerminalV2::_pay: NO_FUNDING_CYCLE");

        IPayDelegate _delegate;

        // The bit that signals whether or not the data source should be used is it bit 37 of the funding cycle's metadata.
        if (fundingCycle.useDataSourceForPay()) {
            (weight, memo, _delegate) = IFundingCycleDataSource(
                fundingCycle.dataSource()
            ).payData(fundingCycle, _payer, _amount, _beneficiary, _memo);
        } else {
            weight = fundingCycle.weight;
            memo = _memo;
        }

        // scope to avoid stack too deep errors. Inspired by uniswap https://github.com/Uniswap/uniswap-v2-periphery/blob/69617118cda519dab608898d62aaa79877a61004/contracts/UniswapV2Router02.sol#L327-L333.
        {
            // Multiply the amount by the funding cycle's weight to determine the amount of tickets to print.
            uint256 _weightedAmount = PRBMathUD60x18.mul(_amount, weight);

            // Only print the tickets that are unreserved.
            tokenCount = PRBMath.mulDiv(
                _weightedAmount,
                // The reserved rate is stored in bits 8-15 of the metadata property.
                200 - fundingCycle.reservedRate(),
                200
            );
            // The minimum amount of unreserved tickets must be printed.
            require(
                tokenCount >= _minReturnedTokens,
                "TerminalV2::_pay: INADEQUATE"
            );

            // Add to the balance of the project.
            balanceOf[_projectId] = balanceOf[_projectId] + _amount;
            // If theres an unreserved weighted amount, print tickets representing this amount for the beneficiary.
            if (tokenCount > 0) {
                // Print the project's tickets for the beneficiary.
                ticketBooth.print(
                    _beneficiary,
                    _projectId,
                    tokenCount,
                    _preferUnstakedTokens
                );
            } else if (_weightedAmount > 0) {
                // Subtract the total weighted amount from the tracker so the full reserved ticket amount can be printed later.
                _processedTokenTrackerOf[_projectId] =
                    _processedTokenTrackerOf[_projectId] -
                    int256(_weightedAmount);
            }
        }

        if (_delegate != IPayDelegate(address(0)))
            _delegate.didPay(
                fundingCycle,
                _payer,
                _amount,
                weight,
                tokenCount,
                _beneficiary,
                _memo
            );
    }

    // /**
    //   @notice
    //   Tap into funds that have been contributed to a project's current funding cycle.

    //   @dev
    //   Anyone can tap funds on a project's behalf.

    //   @param _projectId The ID of the project to which the funding cycle being tapped belongs.
    //   @param _amount The amount being tapped, in the funding cycle's currency.
    //   @param _currency The expected currency being tapped.
    //   @param _minReturnedWei The minimum number of wei that the amount should be valued at.

    //   @return The ID of the funding cycle that was tapped.
    // */
    function tap(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei
    )
        external
        override
        onlyPaymentLayer
        returns (FundingCycle memory fundingCycle, uint256 tappedWeiAmount)
    {
        // Register the funds as tapped. Get the ID of the funding cycle that was tapped.
        fundingCycle = fundingCycles.tap(_projectId, _amount);

        // If there's no funding cycle, there are no funds to tap.
        require(fundingCycle.id > 0, "TerminalV2::tap: NOT_FOUND");

        // Must not be paused.
        require(!fundingCycle.tapPaused(), "TerminalV2::tap: PAUSED");

        // Make sure the currency's match.
        require(
            _currency == fundingCycle.currency,
            "TerminalV2::tap: UNEXPECTED_CURRENCY"
        );

        // The amount of ETH that is being tapped.
        tappedWeiAmount = PRBMathUD60x18.div(
            _amount,
            prices.getETHPriceFor(fundingCycle.currency)
        );

        // The amount being tapped must be at least as much as was expected.
        require(
            _minReturnedWei <= tappedWeiAmount,
            "TerminalV2::tap: INADEQUATE"
        );

        // The amount being tapped must be available.
        require(
            tappedWeiAmount <= balanceOf[_projectId],
            "TerminalV2::tap: INSUFFICIENT_FUNDS"
        );

        // Removed the tapped funds from the project's balance.
        balanceOf[_projectId] = balanceOf[_projectId] - tappedWeiAmount;
    }

    /** 
      @notice Allows a project to send funds from its overflow up to the preconfigured allowance.
      @param _projectId The ID of the project to use the allowance of.
      @param _amount The amount of the allowance to use.
    */
    function useAllowance(uint256 _projectId, uint256 _amount)
        external
        override
        onlyPaymentLayer
        returns (FundingCycle memory fundingCycle)
    {
        // Get a reference to the project's current funding cycle.
        fundingCycle = fundingCycles.currentOf(_projectId);

        require(
            _amount <= balanceOf[_projectId],
            "TerminalV2::tapAllowance: INSUFFICIENT_FUNDS"
        );

        // There must be sufficient allowance available.
        require(
            _amount <= overflowAllowanceOf[_projectId][fundingCycle.configured],
            "TerminalV2DataLayer::decrementAllowance: NOT_ALLOWED"
        );

        // Store the decremented value.
        overflowAllowanceOf[_projectId][fundingCycle.configured] =
            overflowAllowanceOf[_projectId][fundingCycle.configured] -
            _amount;

        balanceOf[_projectId] = balanceOf[_projectId] - _amount;
    }

    // /**
    //   @notice
    //   Addresses can redeem their Tickets to claim the project's overflowed ETH.

    //   @dev
    //   Only a ticket's holder or a designated operator can redeem it.

    //   @param _holder The account to redeem tickets for.
    //   @param _projectId The ID of the project to which the Tickets being redeemed belong.
    //   @param _tokenCount The number of Tickets to redeem.
    //   @param _minReturnedWei The minimum amount of Wei expected in return.
    //   @param _preferUnstaked If the preference is to redeem tickets that have been converted to ERC-20s.

    //   @return amount The amount of ETH that the tickets were redeemed for.
    // */
    function redeem(
        address _holder,
        uint256 _projectId,
        uint256 _tokenCount,
        uint256 _minReturnedWei,
        address payable _beneficiary,
        string calldata _memo,
        bool _preferUnstaked
    )
        external
        override
        onlyPaymentLayer
        returns (
            FundingCycle memory fundingCycle,
            uint256 claimAmount,
            string memory memo
        )
    {
        // The holder must have the specified number of the project's tickets.
        require(
            ticketBooth.balanceOf(_holder, _projectId) >= _tokenCount,
            "TerminalV2::redeem: INSUFFICIENT_TICKETS"
        );

        // Get a reference to the current funding cycle for the project.
        fundingCycle = fundingCycles.currentOf(_projectId);

        // Must not be paused.
        require(fundingCycle.redeemPaused(), "TerminalV2:redeem: PAUSED");

        IRedeemDelegate _delegate;

        // The bit that signals whether or not the delegate should be used is it bit 36 of the funding cycle's metadata.
        if (fundingCycle.useDataSourceForRedeem()) {
            (claimAmount, memo, _delegate) = IFundingCycleDataSource(
                fundingCycle.dataSource()
            ).redeemData(
                    fundingCycle,
                    _holder,
                    _tokenCount,
                    _beneficiary,
                    _memo
                );
        } else {
            claimAmount = _claimableOverflowOf(fundingCycle, _tokenCount);
            memo = _memo;
        }

        // The amount being claimed must be at least as much as was expected.
        require(
            claimAmount >= _minReturnedWei,
            "TerminalV2::redeem: INADEQUATE"
        );

        require(
            claimAmount <= balanceOf[_projectId],
            "TerminalV2::redeem: INSUFFICIENT_FUNDS"
        );

        // Redeem the tickets, which burns them.
        if (_tokenCount > 0) {
            _subtractFromTokenTracker(_projectId, _tokenCount);
            ticketBooth.redeem(
                _holder,
                _projectId,
                _tokenCount,
                _preferUnstaked
            );
        }

        // Remove the redeemed funds from the project's balance.
        if (claimAmount > 0)
            balanceOf[_projectId] = balanceOf[_projectId] - claimAmount;

        // If a the delegate shouldn't get called back, don't return it.
        if (_delegate != IRedeemDelegate(address(0)))
            _delegate.didRedeem(
                fundingCycle,
                _holder,
                _tokenCount,
                claimAmount,
                _beneficiary,
                memo
            );
    }

    function burn(
        address _holder,
        uint256 _projectId,
        uint256 _tokenCount,
        string calldata _memo,
        bool _preferUnstaked
    ) external override {
        require(_tokenCount > 0, "TerminalV2DataLayer::burn: NO_OP");
        _subtractFromTokenTracker(_projectId, _tokenCount);
        ticketBooth.redeem(_holder, _projectId, _tokenCount, _preferUnstaked);
        emit Burn(_holder, _projectId, _tokenCount, _memo, msg.sender);
    }

    /**
      @notice
      Allows a project owner to migrate its funds and operations to a new contract.

      @dev
      Only a project's owner or a designated operator can migrate it.

      @param _projectId The ID of the project being migrated.
      @param _to The contract that will gain the project's funds.
    */
    function migrate(uint256 _projectId, ITerminal _to)
        external
        override
        onlyPaymentLayer
        returns (uint256 balance)
    {
        // This TerminalV1 must be the project's current terminal.
        require(
            terminalDirectory.terminalOf(_projectId) == this,
            "TerminalV2::migrate: UNAUTHORIZED"
        );

        // The migration destination must be allowed.
        require(migrationIsAllowed[_to], "TerminalV2::migrate: NOT_ALLOWED");

        // All reserved tickets must be printed before migrating.
        if (
            uint256(_processedTokenTrackerOf[_projectId]) !=
            ticketBooth.totalSupplyOf(_projectId)
        ) _mintReservedTokens(_projectId, "");

        balance = balanceOf[_projectId];

        // Set the balance to 0.
        balanceOf[_projectId] = 0;

        // Switch the direct payment terminal.
        terminalDirectory.setTerminal(_projectId, _to);
    }

    function addToBalance(uint256 _projectId) external payable override {
        require(msg.sender != address(paymentLayer), "TODO BAD");
        // This contract should not keep any ETH. It should relay it all
        // to the TerminalVault that owns this terminal.
        paymentLayer.addToBalance{value: msg.value}(_projectId);
    }

    /**
      @notice
      Receives and allocates funds belonging to the specified project.

      @param _amount The amount being added.
      @param _projectId The ID of the project to which the funds received belong.
    */
    function addToBalance(uint256 _amount, uint256 _projectId)
        external
        payable
        override
        onlyPaymentLayer
    {
        // The amount must be positive.
        require(_amount > 0, "TerminalV1::addToBalance: BAD_AMOUNT");
        // Set the balance.
        balanceOf[_projectId] = balanceOf[_projectId] + msg.value;
    }

    function prepToReceiveBalanceFor(uint256 _projectId) external override {
        // Set the processed ticket tracker if this isnt the current terminal for the project.
        require(terminalDirectory.terminalOf(_projectId) != this, "TODO BAD");
        // Set the tracker to be the new total supply.
        _processedTokenTrackerOf[_projectId] = int256(
            ticketBooth.totalSupplyOf(_projectId)
        );
    }

    /**
      @notice
      Adds to the contract addresses that projects can migrate their Tickets to.

      @dev
      Only the owner can add a contract to the migration allow list.

      @param _contract The contract to allow.
    */
    function allowMigration(ITerminal _contract) external override onlyOwner {
        // Can't allow the zero address.
        require(
            _contract != ITerminal(address(0)),
            "TerminalV2::allowMigration: ZERO_ADDRESS"
        );

        // Toggle the contract as allowed.
        migrationIsAllowed[_contract] = !migrationIsAllowed[_contract];

        emit AllowMigration(_contract);
    }

    function setPaymentLayer(ITerminalV2PaymentLayer _paymentLayer)
        external
        override
        onlyOwner
    {
        paymentLayer = _paymentLayer;
        emit SetPaymentLayer(_paymentLayer, msg.sender);
    }

    /**
      @notice
      Mints all reserved tokens for a project.

      @param _projectId The ID of the project to which the reserved tokens belong.

      @return amount The amount of tokens that are being printed.
    */
    function mintReservedTokens(uint256 _projectId, string memory _memo)
        external
        override
        nonReentrant
        returns (uint256 amount)
    {
        return _mintReservedTokens(_projectId, _memo);
    }

    // --- private helper functions --- //

    /**
      @notice
      See the documentation for 'pay'.
    */

    /**
      @notice
      Validate and pack the funding cycle metadata.

      @param _metadata The metadata to validate and pack.

      @return packed The packed uint256 of all metadata params. The first 8 bytes specify the version.
     */
    function _validateAndPackFundingCycleMetadata(
        FundingCycleMetadataV2 memory _metadata
    ) private pure returns (uint256 packed) {
        // The reserved project ticket rate must be less than or equal to 200.
        require(
            _metadata.reservedRate <= 200,
            "TerminalV2::_validateAndPackFundingCycleMetadata: BAD_RESERVED_RATE"
        );

        // The redemption rate must be between 0 and 200.
        require(
            _metadata.redemptionRate <= 200,
            "TerminalV2::_validateAndPackFundingCycleMetadata: BAD_REDEMPTION_RATE"
        );

        // The ballot redemption rate must be less than or equal to 200.
        require(
            _metadata.ballotRedemptionRate <= 200,
            "TerminalV2::_validateAndPackFundingCycleMetadata: BAD_BALLOT_REDEMPTION_RATE"
        );

        // version 0 in the first 8 bytes.
        packed = 0;
        // reserved rate in bits 8-15.
        packed |= _metadata.reservedRate << 8;
        // bonding curve in bits 16-23.
        packed |= _metadata.redemptionRate << 16;
        // reconfiguration bonding curve rate in bits 24-31.
        packed |= _metadata.ballotRedemptionRate << 24;
        // pause pay in bit 32.
        packed |= (_metadata.pausePay ? 1 : 0) << 32;
        // pause tap in bit 33.
        packed |= (_metadata.pauseTap ? 1 : 0) << 33;
        // pause redeem  in bit 34.
        packed |= (_metadata.pauseRedeem ? 1 : 0) << 34;
        // use pay data source in bit 32.
        packed |= (_metadata.useDataSourceForPay ? 1 : 0) << 35;
        // use redeem data source in bit 33.
        packed |= (_metadata.useDataSourceForRedeem ? 1 : 0) << 36;
        // delegate address in bits 37-196.
        packed |= uint160(address(_metadata.dataSource)) << 37;
    }

    /**
      @notice See docs for `printReservedTokens`
    */
    function _mintReservedTokens(uint256 _projectId, string memory _memo)
        private
        returns (uint256 amount)
    {
        // Get the current funding cycle to read the reserved rate from.
        FundingCycle memory _fundingCycle = fundingCycles.currentOf(_projectId);

        // If there's no funding cycle, there's no reserved tickets to print.
        if (_fundingCycle.number == 0) return 0;

        // Get a reference to new total supply of tickets before printing reserved tickets.
        uint256 _totalTokens = ticketBooth.totalSupplyOf(_projectId);

        // Get a reference to the number of tickets that need to be printed.
        // If there's no funding cycle, there's no tickets to print.
        // The reserved rate is in bits 8-15 of the metadata.
        amount = _reservedTokenAmountFrom(
            _processedTokenTrackerOf[_projectId],
            _fundingCycle.reservedRate(),
            _totalTokens
        );

        // Set the tracker to be the new total supply.
        _processedTokenTrackerOf[_projectId] = int256(_totalTokens + amount);

        // Get a reference to the project owner.
        address _owner = projects.ownerOf(_projectId);

        // Distribute tickets to mods and get a reference to the leftover amount to print after all mods have had their share printed.
        uint256 _leftoverTicketAmount = amount == 0
            ? 0
            : _distributeToTicketMods(_fundingCycle, amount);

        // Print if there is something to print.
        if (_leftoverTicketAmount > 0)
            ticketBooth.print(_owner, _projectId, _leftoverTicketAmount, false);

        emit PrintReserveTokens(
            _fundingCycle.number,
            _projectId,
            _owner,
            amount,
            _leftoverTicketAmount,
            _memo,
            msg.sender
        );
    }

    function _claimableOverflowOf(
        FundingCycle memory _fundingCycle,
        uint256 _tokenCount
    ) private view returns (uint256) {
        // Get the amount of current overflow.
        uint256 _currentOverflow = _overflowFrom(_fundingCycle);

        // If there is no overflow, nothing is claimable.
        if (_currentOverflow == 0) return 0;

        // Get the total number of tickets in circulation.
        uint256 _totalSupply = ticketBooth.totalSupplyOf(
            _fundingCycle.projectId
        );

        // Get the number of reserved tickets the project has.
        uint256 _reservedTokenAmount = _reservedTokenAmountFrom(
            _processedTokenTrackerOf[_fundingCycle.projectId],
            _fundingCycle.reservedRate(),
            _totalSupply
        );

        // If there are reserved tickets, add them to the total supply.
        if (_reservedTokenAmount > 0)
            _totalSupply = _totalSupply + _reservedTokenAmount;

        // If the amount being redeemed is the the total supply, return the rest of the overflow.
        if (_tokenCount == _totalSupply) return _currentOverflow;

        // Get a reference to the linear proportion.
        uint256 _base = PRBMath.mulDiv(
            _currentOverflow,
            _tokenCount,
            _totalSupply
        );

        // Use the ballot redemption rate if the queued cycle is pending approval according to the previous funding cycle's ballot.
        uint256 _redemptionRate = fundingCycles.currentBallotStateOf(
            _fundingCycle.projectId
        ) == BallotState.Active
            ? _fundingCycle.ballotRedemptionRate()
            : _fundingCycle.redemptionRate();

        // These conditions are all part of the same curve. Edge conditions are separated because fewer operation are necessary.
        if (_redemptionRate == 200) return _base;
        if (_redemptionRate == 0) return 0;
        return
            PRBMath.mulDiv(
                _base,
                _redemptionRate +
                    PRBMath.mulDiv(
                        _tokenCount,
                        200 - _redemptionRate,
                        _totalSupply
                    ),
                200
            );
    }

    /**
      @notice
      Gets the amount overflowed in relation to the provided funding cycle.

      @dev
      This amount changes as the price of ETH changes against the funding cycle's currency.

      @param _currentFundingCycle The ID of the funding cycle to base the overflow on.

      @return overflow The current overflow of funds.
    */
    function _overflowFrom(FundingCycle memory _currentFundingCycle)
        private
        view
        returns (uint256)
    {
        // Get the current balance of the project.
        uint256 _balanceOf = balanceOf[_currentFundingCycle.projectId];

        if (_balanceOf == 0) return 0;

        // Get a reference to the amount still tappable in the current funding cycle.
        uint256 _limit = _currentFundingCycle.target -
            _currentFundingCycle.tapped;

        // The amount of ETH that the owner could currently still tap if its available. This amount isn't considered overflow.
        uint256 _ethLimit = _limit == 0
            ? 0 // Get the current price of ETH.
            : PRBMathUD60x18.div(
                _limit,
                prices.getETHPriceFor(_currentFundingCycle.currency)
            );

        // Overflow is the balance of this project minus the reserved amount.
        return _balanceOf < _ethLimit ? 0 : _balanceOf - _ethLimit;
    }

    /**
      @notice
      distributed tickets to the mods for the specified funding cycle.

      @param _fundingCycle The funding cycle to base the ticket distribution on.
      @param _amount The total amount of tickets to print.

      @return leftoverAmount If the mod percents dont add up to 100%, the leftover amount is returned.

    */
    function _distributeToTicketMods(
        FundingCycle memory _fundingCycle,
        uint256 _amount
    ) private returns (uint256 leftoverAmount) {
        // Set the leftover amount to the initial amount.
        leftoverAmount = _amount;

        // Get a reference to the project's ticket mods.
        TicketMod[] memory _mods = modStore.ticketModsOf(
            _fundingCycle.projectId,
            _fundingCycle.configured
        );

        //Transfer between all mods.
        for (uint256 _i = 0; _i < _mods.length; _i++) {
            // Get a reference to the mod being iterated on.
            TicketMod memory _mod = _mods[_i];

            // The amount to send towards mods. Mods percents are out of 10000.
            uint256 _modCut = PRBMath.mulDiv(_amount, _mod.percent, 10000);

            // Print tickets for the mod if needed.
            if (_modCut > 0)
                ticketBooth.print(
                    _mod.beneficiary,
                    _fundingCycle.projectId,
                    _modCut,
                    _mod.preferUnstaked
                );

            // Subtract from the amount to be sent to the beneficiary.
            leftoverAmount = leftoverAmount - _modCut;

            emit DistributeToTicketMod(
                _fundingCycle.number,
                _fundingCycle.id,
                _fundingCycle.projectId,
                _mod,
                _modCut,
                msg.sender
            );
        }
    }

    function _subtractFromTokenTracker(uint256 _projectId, uint256 _amount)
        private
    {
        // Get a reference to the processed ticket tracker for the project.
        int256 _processedTokenTracker = _processedTokenTrackerOf[_projectId];

        // Subtract the count from the processed ticket tracker.
        // Subtract from processed tickets so that the difference between whats been processed and the
        // total supply remains the same.
        // If there are at least as many processed tickets as there are tickets being redeemed,
        // the processed ticket tracker of the project will be positive. Otherwise it will be negative.
        _processedTokenTrackerOf[_projectId] = _processedTokenTracker < 0 // If the tracker is negative, add the count and reverse it.
            ? -int256(uint256(-_processedTokenTracker) + _amount) // the tracker is less than the count, subtract it from the count and reverse it.
            : _processedTokenTracker < int256(_amount)
            ? -(int256(_amount) - _processedTokenTracker) // simply subtract otherwise.
            : _processedTokenTracker - int256(_amount);
    }

    function _setOverflowAllowance(
        uint256 _amount,
        uint256 _projectId,
        uint256 _configuration
    ) private {
        overflowAllowanceOf[_projectId][_configuration] = _amount;

        emit SetOverflowAllowance(
            _projectId,
            _configuration,
            _amount,
            msg.sender
        );
    }

    /**
      @notice
      Gets the amount of reserved tickets currently tracked for a project given a reserved rate.

      @param _processedTokenTracker The tracker to make the calculation with.
      @param _reservedRate The reserved rate to use to make the calculation.
      @param _totalEligibleTickets The total amount to make the calculation with.

      @return amount reserved ticket amount.
    */
    function _reservedTokenAmountFrom(
        int256 _processedTokenTracker,
        uint256 _reservedRate,
        uint256 _totalEligibleTickets
    ) private pure returns (uint256) {
        // Get a reference to the amount of tickets that are unprocessed.
        uint256 _unprocessedTicketBalanceOf = _processedTokenTracker >= 0 // preconfigure tickets shouldn't contribute to the reserved ticket amount.
            ? _totalEligibleTickets - uint256(_processedTokenTracker)
            : _totalEligibleTickets + uint256(-_processedTokenTracker);

        // If there are no unprocessed tickets, return.
        if (_unprocessedTicketBalanceOf == 0) return 0;

        // If all tickets are reserved, return the full unprocessed amount.
        if (_reservedRate == 200) return _unprocessedTicketBalanceOf;

        return
            PRBMath.mulDiv(
                _unprocessedTicketBalanceOf,
                200,
                200 - _reservedRate
            ) - _unprocessedTicketBalanceOf;
    }
}
