// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@paulrberg/contracts/math/PRBMath.sol";
import "@paulrberg/contracts/math/PRBMathUD60x18.sol";

import "./libraries/Operations.sol";
import "./libraries/Operations2.sol";
import "./libraries/SplitsGroups.sol";
import "./libraries/FundingCycleMetadataResolver.sol";

// Inheritance
import "./interfaces/ITerminalV2DataLayer.sol";
import "./interfaces/ITerminalDataLayer.sol";
import "./abstract/Operatable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
  @notice 
  This contract stiches together funding cycles and treasury tokens. It makes sure all activity is accounted for and correct. 

  @dev 
  Each project can only have one terminal registered at a time with the TerminalDirectory. This is how the outside world knows where to send money when trying to pay a project.
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
    Operatable,
    Ownable,
    ReentrancyGuard
{
    // A library that parses the packed funding cycle metadata into a more friendly format.
    using FundingCycleMetadataResolver for FundingCycle;

    // Modifier to only allow the payment layer to call the function.
    modifier onlyPaymentLayer() {
        require(msg.sender == address(paymentLayer), "TV2DL: UNAUTHORIZED");
        _;
    }

    //*********************************************************************//
    // --------------------- private stored properties ------------------- //
    //*********************************************************************//

    // The difference between the processed token tracker of a project and the project's token's total supply is the amount of tokens that
    // still need to have reserves minted against them.
    mapping(uint256 => int256) private _processedTokenTrackerOf;

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice The Projects contract which mints ERC-721's that represent project ownership.
    IProjects public immutable override projects;

    /// @notice The contract storing all funding cycle configurations.
    IFundingCycles public immutable override fundingCycles;

    /// @notice The contract that manages token minting and burning.
    ITicketBooth public immutable override ticketBooth;

    /// @notice The contract that stores splits for each project.
    ISplitsStore public immutable override splitsStore;

    /// @notice The contract that exposes price feeds.
    IPrices public immutable override prices;

    /// @notice The directory of terminals.
    ITerminalDirectory public immutable override terminalDirectory;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The amount of ETH that each project has.
    mapping(uint256 => uint256) public override balanceOf;

    /// @notice Whether or not a particular contract is available for projects to migrate their funds to.
    mapping(ITerminal => bool) public override migrationIsAllowed;

    /// @notice The amount of overflow that a project is allowed to tap into on-demand.
    mapping(uint256 => mapping(uint256 => uint256))
        public
        override overflowAllowanceOf;

    /// @notice The contract that stores funds, and manages inflows/outflows.
    ITerminalV2PaymentLayer public override paymentLayer;

    /// @notice The platform fee percent. Out of 200.
    uint256 public override fee = 10;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

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

    //*********************************************************************//
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /**
      @param _operatorStore A contract storing operator assignments.
      @param _projects A Projects contract which mints ERC-721's that represent project ownership and transfers.
      @param _fundingCycles The contract storing all funding cycle configurations.
      @param _ticketBooth The contract that manages token minting and burning.
      @param _splitsStore The contract that stores splits for each project.
      @param _prices The contract that exposes price feeds.
      @param _terminalDirectory The directory of terminals.
    */
    constructor(
        IOperatorStore _operatorStore,
        IProjects _projects,
        IFundingCycles _fundingCycles,
        ITicketBooth _ticketBooth,
        ISplitsStore _splitsStore,
        IPrices _prices,
        ITerminalDirectory _terminalDirectory
    ) Operatable(_operatorStore) {
        projects = _projects;
        fundingCycles = _fundingCycles;
        ticketBooth = _ticketBooth;
        splitsStore = _splitsStore;
        prices = _prices;
        terminalDirectory = _terminalDirectory;
    }

    //*********************************************************************//
    // --------------------- external transactions ----------------------- //
    //*********************************************************************//

    /**
      @notice
      Creates a project. This will mint an ERC-721 into the `_owner`'s account, configure a first funding cycle, and set up any splits.

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
      @param _metadata A struct specifying the TerminalV2 specific params that a funding cycle can have.
        @dev _metadata.reservedRate A number from 0-200 (0-100%) indicating the percentage of each contribution's newly minted tokens that will be reserved for the token splits.
        @dev _metadata.redemptionRate The rate from 0-200 (0-100%) that tunes the bonding curve according to which a project's tokens can be redeemed for overflow.
          The bonding curve formula is https://www.desmos.com/calculator/sp9ru6zbpk
          where x is _count, o is _currentOverflow, s is _totalSupply, and r is _redemptionRate.
        @dev _metadata.ballotRedemptionRate The redemption rate to apply when there is an active ballot.
        @dev _metadata.pausePay Whether or not the pay functionality should be paused during this cycle.
        @dev _metadata.pauseWithdraw Whether or not the withdraw functionality should be paused during this cycle.
        @dev _metadata.pauseRedeem Whether or not the redeem functionality should be paused during this cycle.
        @dev _metadata.pauseMint Whether or not the mint functionality should be paused during this cycle.
        @dev _metadata.pauseBurn Whether or not the burn functionality should be paused during this cycle.
        @dev _metadata.useDataSourceForPay Whether or not the data source should be used when processing a payment.
        @dev _metadata.useDataSourceForRedeem Whether or not the data source should be used when processing a redemption.
        @dev _metadata.dataSource A contract that exposes data that can be used within pay and redeem transactions. Must adhere to IFundingCycleDataSource.
      @param _overflowAllowance The amount, in wei (18 decimals), of ETH that a project can use from its own overflow on-demand.
      @param _payoutSplits Any payout splits to set.
      @param _reservedTokenSplits Any reserved token splits to set.
    */
    function launchProject(
        address _owner,
        bytes32 _handle,
        string calldata _uri,
        FundingCycleProperties calldata _properties,
        FundingCycleMetadataV2 calldata _metadata,
        uint256 _overflowAllowance,
        Split[] memory _payoutSplits,
        Split[] memory _reservedTokenSplits
    ) external override {
        // Make sure the metadata is validated and packed into a uint256.
        uint256 _packedMetadata = _validateAndPackFundingCycleMetadata(
            _metadata
        );

        // Create the project for the owner. This this contract as the project's terminal,
        // which will give it exclusive access to manage the project's funding cycles and tokens.
        uint256 _projectId = projects.create(_owner, _handle, _uri, this);

        _configure(
            _projectId,
            _properties,
            _packedMetadata,
            _overflowAllowance,
            _payoutSplits,
            _reservedTokenSplits,
            true
        );
    }

    /**
      @notice
      Configures the properties of the current funding cycle if the project hasn't distributed tokens yet, or
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
      @param _metadata A struct specifying the TerminalV2 specific params that a funding cycle can have.
        @dev _metadata.reservedRate A number from 0-200 (0-100%) indicating the percentage of each contribution's newly minted tokens that will be reserved for the token splits.
        @dev _metadata.redemptionRate The rate from 0-200 (0-100%) that tunes the bonding curve according to which a project's tokens can be redeemed for overflow.
          The bonding curve formula is https://www.desmos.com/calculator/sp9ru6zbpk
          where x is _count, o is _currentOverflow, s is _totalSupply, and r is _redemptionRate.
        @dev _metadata.ballotRedemptionRate The redemption rate to apply when there is an active ballot.
        @dev _metadata.pausePay Whether or not the pay functionality should be paused during this cycle.
        @dev _metadata.pauseWithdraw Whether or not the withdraw functionality should be paused during this cycle.
        @dev _metadata.pauseRedeem Whether or not the redeem functionality should be paused during this cycle.
        @dev _metadata.pauseMint Whether or not the mint functionality should be paused during this cycle.
        @dev _metadata.pauseBurn Whether or not the burn functionality should be paused during this cycle.
        @dev _metadata.useDataSourceForPay Whether or not the data source should be used when processing a payment.
        @dev _metadata.useDataSourceForRedeem Whether or not the data source should be used when processing a redemption.
        @dev _metadata.dataSource A contract that exposes data that can be used within pay and redeem transactions. Must adhere to IFundingCycleDataSource.
      @param _overflowAllowance The amount, in wei (18 decimals), of ETH that a project can use from its own overflow on-demand.
      @param _payoutSplits Any payout splits to set.
      @param _reservedTokenSplits Any reserved token splits to set.

      @return The ID of the funding cycle that was successfully configured.
    */
    function reconfigureFundingCycles(
        uint256 _projectId,
        FundingCycleProperties calldata _properties,
        FundingCycleMetadataV2 calldata _metadata,
        uint256 _overflowAllowance,
        Split[] memory _payoutSplits,
        Split[] memory _reservedTokenSplits
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
        ) _distributeReservedTokens(_projectId, "");

        // Configure the active project if its tokens have yet to be minted.
        bool _shouldConfigureActive = ticketBooth.totalSupplyOf(_projectId) ==
            0;

        return
            _configure(
                _projectId,
                _properties,
                _packedMetadata,
                _overflowAllowance,
                _payoutSplits,
                _reservedTokenSplits,
                _shouldConfigureActive
            );
    }

    /**
      @notice
      Mint new token supply into an account.

      @dev
      Only a project's owner or a designated operator can mint it.

      @param _projectId The ID of the project to which the tokens being burned belong.
      @param _amount The amount to base the token mint off of, in wei (10^18)
      @param _currency The currency of the amount to base the token mint off of. Send 0 for ETH or 1 for USD.
      @param _weight The number of tokens minted per ETH amount specified is determined by the weight. If this is left at 0, the weight of the current funding cycle is used (10^24, 18 decimals). 
        For example, if the `_currency` specified is ETH and the `_weight` specified is 10^20, then an `_amount` of 1 ETH (sent as 10^18) will mint 100 tokens.
      @param _beneficiary The account that the tokens are being minted for.
      @param _memo A memo to pass along to the emitted event.
      @param _preferUnstakedTokens Whether ERC20's should be burned first if they have been issued.

      @return tokenCount The amount of tokens minted.
    */
    function mintTokens(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _weight,
        address _beneficiary,
        string calldata _memo,
        bool _preferUnstakedTokens
    )
        external
        override
        nonReentrant
        requirePermission(
            projects.ownerOf(_projectId),
            _projectId,
            Operations2.Mint
        )
        returns (uint256 tokenCount)
    {
        // Can't send to the zero address.
        require(_beneficiary != address(0), "TV2DL: ZERO_ADDRESS");

        // There should be tokens to mint.
        require(_amount > 0, "TV2DL: NO_OP");

        // Get a reference to the project's current funding cycle.
        FundingCycle memory _fundingCycle = fundingCycles.currentOf(_projectId);

        // The current funding cycle must not be paused.
        require(_fundingCycle.mintPaused(), "TV2DL: PAUSED");

        // If a weight isn't specified, get the current funding cycle to read the weight from. If there's no current funding cycle, use the base weight.
        _weight = _weight > 0 ? _weight : _fundingCycle.number > 0
            ? _fundingCycle.weight
            : fundingCycles.BASE_WEIGHT();

        // Multiply the amount with the weight to determine the number of tokens to mint.
        tokenCount = PRBMathUD60x18.mul(
            PRBMathUD60x18.div(_amount, prices.getETHPriceFor(_currency)),
            _weight
        );

        // Set the minted tokens as processed so that reserved tokens cant be minted against them.
        _processedTokenTrackerOf[_projectId] =
            _processedTokenTrackerOf[_projectId] +
            int256(tokenCount);

        // Redeem the tokens, which burns them.
        ticketBooth.print(
            _beneficiary,
            _projectId,
            tokenCount,
            _preferUnstakedTokens
        );

        emit Mint(
            _beneficiary,
            _projectId,
            _amount,
            _currency,
            _weight,
            tokenCount,
            _memo,
            msg.sender
        );
    }

    /**
      @notice
      Burns a token holder's supply.

      @dev
      Only a token's holder or a designated operator can burn it.

      @param _holder The account that is having its tokens burned.
      @param _projectId The ID of the project to which the tokens being burned belong.
      @param _tokenCount The number of tokens to burn.
      @param _memo A memo to pass along to the emitted event.
      @param _preferUnstakedTokens Whether ERC20's should be burned first if they have been issued.

    */
    function burnTokens(
        address _holder,
        uint256 _projectId,
        uint256 _tokenCount,
        string calldata _memo,
        bool _preferUnstakedTokens
    )
        external
        override
        nonReentrant
        requirePermissionAllowingWildcardDomain(
            _holder,
            _projectId,
            Operations2.Burn
        )
    {
        // There should be tokens to burn
        require(_tokenCount > 0, "TV2DL: NO_OP");

        // Get a reference to the project's current funding cycle.
        FundingCycle memory _fundingCycle = fundingCycles.currentOf(_projectId);

        // The current funding cycle must not be paused.
        require(_fundingCycle.burnPaused(), "TV2DL: PAUSED");

        // Update the token tracker so that reserved tokens will still be correctly mintable.
        _subtractFromTokenTracker(_projectId, _tokenCount);
        // Redeem the tokens, which burns them.
        ticketBooth.redeem(
            _holder,
            _projectId,
            _tokenCount,
            _preferUnstakedTokens
        );
        emit Burn(_holder, _projectId, _tokenCount, _memo, msg.sender);
    }

    /**
      @notice
      Mints and distributes all outstanding reserved tokens for a project.

      @param _projectId The ID of the project to which the reserved tokens belong.
      @param _memo A memo to leave with the emitted event.

      @return The amount of reserved tokens that were minted.
    */
    function distributeReservedTokens(uint256 _projectId, string memory _memo)
        external
        override
        nonReentrant
        returns (uint256)
    {
        return _distributeReservedTokens(_projectId, _memo);
    }

    /**
      @notice
      Sets up any peice of internal state necessary for the specified project to migrate to this terminal.

      @dev
      This must be called before this contract is the current terminal for the project.

      @dev
      This function can be called many times, but must be called in the same transaction that migrates a project to this terminal.

      @param _projectId The ID of the project that is being migrated to this terminal.
    */
    function prepForMigrationOf(uint256 _projectId) external override {
        // This function can only be called if this contract isn't already the project's current terminal.
        require(
            terminalDirectory.terminalOf(_projectId) != this,
            "TV2DL: NOT_ALLOWED"
        );
        // Set the tracker to be the total supply of tokens so that there's no reserved token supply to mint upon migration.
        _processedTokenTrackerOf[_projectId] = int256(
            ticketBooth.totalSupplyOf(_projectId)
        );
    }

    //*********************************************************************//
    // --- external transactions only accessible by the payment layer ---- //
    //*********************************************************************//

    /**
      @notice
      Records newly contributed ETH to a project made at the payment layer.

      @dev
      Mint's the project's tokens according to values provided by a configured data source. If no data source is configured, mints tokens proportional to the amount of the contribution.

      @dev
      The msg.value is the amount of the contribution in wei.

      @dev
      Only the payment layer can record a payment.

      @param _payer The original address that sent the payment to the payment layer.
      @param _amount The amount that is being paid.
      @param _projectId The ID of the project being contribute to.
      @param _beneficiary The address that should receive benefits from the payment.
      @param _minReturnedTokens The minimum number of tokens expected in return.
      @param _memo A memo that will be included in the published event.
      @param _preferUnstakedTokens Whether ERC20's should be unstaked automatically if they have been issued.

      @return fundingCycle The funding cycle during which payment was made.
      @return weight The weight according to which new token supply was minted.
      @return tokenCount The number of tokens that were minted.
      @return memo A memo that should be included in the published event.
    */
    function recordPayment(
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

        // The project must have a funding cycle configured.
        require(fundingCycle.number > 0, "TV2DL: NOT_FOUND");

        // Must not be paused.
        require(!fundingCycle.payPaused(), "TV2DL: PAUSED");

        // Save a reference to the delegate to use.
        IPayDelegate _delegate;

        // If the funding cycle has configured a data source, use it to derive a weight and memo.
        if (fundingCycle.useDataSourceForPay()) {
            (weight, memo, _delegate) = fundingCycle.dataSource().payData(
                _payer,
                _amount,
                fundingCycle.weight,
                fundingCycle.reservedRate(),
                _beneficiary,
                _memo
            );
            // Otherwise use the funding cycle's weight
        } else {
            weight = fundingCycle.weight;
            memo = _memo;
        }

        // Scope to avoid stack too deep errors.
        // Inspired by uniswap https://github.com/Uniswap/uniswap-v2-periphery/blob/69617118cda519dab608898d62aaa79877a61004/contracts/UniswapV2Router02.sol#L327-L333.
        {
            // Multiply the amount by the weight to determine the amount of tokens to mint.
            uint256 _weightedAmount = PRBMathUD60x18.mul(_amount, weight);

            // Only print the tokens that are unreserved.
            tokenCount = PRBMath.mulDiv(
                _weightedAmount,
                200 - fundingCycle.reservedRate(),
                200
            );

            // The token count must be greater than or equal to the minimum expected.
            require(tokenCount >= _minReturnedTokens, "TV2DL: INADEQUATE");

            // Add the amount to the balance of the project.
            balanceOf[_projectId] = balanceOf[_projectId] + _amount;

            // Mint tokens if needed.
            if (tokenCount > 0) {
                // Mint the project's tokens for the beneficiary.
                ticketBooth.print(
                    _beneficiary,
                    _projectId,
                    tokenCount,
                    _preferUnstakedTokens
                );
                // If all tokens are reserved, updated the token tracker to reflect this.
            } else if (_weightedAmount > 0) {
                // Subtract the total weighted amount from the tracker so the full reserved token amount can be printed later.
                _processedTokenTrackerOf[_projectId] =
                    _processedTokenTrackerOf[_projectId] -
                    int256(_weightedAmount);
            }
        }

        // If a delegate was returned by the data source, issue a callback to it.
        if (_delegate != IPayDelegate(address(0)))
            _delegate.didPay(
                _payer,
                _amount,
                weight,
                tokenCount,
                _beneficiary,
                _memo
            );
    }

    /**
      @notice
      Records newly withdrawn funds for a project made at the payment layer.

      @dev
      Only the payment layer can record a withdrawal.

      @param _projectId The ID of the project that is having funds withdrawn.
      @param _amount The amount being withdrawn. Send as wei (18 decimals).
      @param _currency The expected currency of the `_amount` being tapped. This must match the project's current funding cycle's currency.
      @param _minReturnedWei The minimum number of wei that should be withdrawn.

      @return fundingCycle The funding cycle during which the withdrawal was made.
      @return withdrawnAmount The amount withdrawn.
    */
    function recordWithdrawal(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei
    )
        external
        override
        onlyPaymentLayer
        returns (FundingCycle memory fundingCycle, uint256 withdrawnAmount)
    {
        // Registers the funds as withdrawn and gets the ID of the funding cycle during which this withdrawal is being made.
        fundingCycle = fundingCycles.tap(_projectId, _amount);

        // Funds cannot be withdrawn if there's no funding cycle.
        require(fundingCycle.id > 0, "TV2DL: NOT_FOUND");

        // The funding cycle must not be paused.
        require(!fundingCycle.tapPaused(), "TV2DL: PAUSED");

        // Make sure the currencies match.
        require(
            _currency == fundingCycle.currency,
            "TV2DL: UNEXPECTED_CURRENCY"
        );

        // Convert the amount to wei.
        withdrawnAmount = PRBMathUD60x18.div(
            _amount,
            prices.getETHPriceFor(fundingCycle.currency)
        );

        // The amount being withdrawn must be at least as much as was expected.
        require(_minReturnedWei <= withdrawnAmount, "TV2DL: INADEQUATE");

        // The amount being withdrawn must be available.
        require(
            withdrawnAmount <= balanceOf[_projectId],
            "TV2DL: INSUFFICIENT_FUNDS"
        );

        // Removed the withdrawn funds from the project's balance.
        balanceOf[_projectId] = balanceOf[_projectId] - withdrawnAmount;
    }

    /** 
      @notice 
      Records newly used allowance funds of a project made at the payment layer.

      @dev
      Only the payment layer can record used allowance.

      @param _projectId The ID of the project to use the allowance of.
      @param _amount The amount of the allowance to use.

      @return fundingCycle The funding cycle during which the withdrawal is being made.
      @return withdrawnAmount The amount withdrawn.
    */
    function recordUsedAllowance(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei
    )
        external
        override
        onlyPaymentLayer
        returns (FundingCycle memory fundingCycle, uint256 withdrawnAmount)
    {
        // Get a reference to the project's current funding cycle.
        fundingCycle = fundingCycles.currentOf(_projectId);

        // Make sure the currencies match.
        require(
            _currency == fundingCycle.currency,
            "TV2DL: UNEXPECTED_CURRENCY"
        );

        // Convert the amount to wei.
        withdrawnAmount = PRBMathUD60x18.div(
            _amount,
            prices.getETHPriceFor(fundingCycle.currency)
        );

        // There must be sufficient allowance available.
        require(
            withdrawnAmount <=
                overflowAllowanceOf[_projectId][fundingCycle.configured],
            "TV2DL: NOT_ALLOWED"
        );

        // The amount being withdrawn must be at least as much as was expected.
        require(_minReturnedWei <= withdrawnAmount, "TV2DL: INADEQUATE");

        // The amount being withdrawn must be available.
        require(
            withdrawnAmount <= balanceOf[_projectId],
            "TV2DL: INSUFFICIENT_FUNDS"
        );

        // Store the decremented value.
        overflowAllowanceOf[_projectId][fundingCycle.configured] =
            overflowAllowanceOf[_projectId][fundingCycle.configured] -
            withdrawnAmount;

        // Update the project's balance.
        balanceOf[_projectId] = balanceOf[_projectId] - withdrawnAmount;
    }

    /**
      @notice
      Records newly redeemed tokens of a project made at the payment layer.

      @dev
      Only the payment layer can record redemptions.

      @param _holder The account that is having its tokens redeemed.
      @param _projectId The ID of the project to which the tokens being redeemed belong.
      @param _tokenCount The number of tokens to redeem.
      @param _minReturnedWei The minimum amount of wei expected in return.
      @param _beneficiary The account that will benefit from the claimed amount.
      @param _memo A memo to pass along to the emitted event.
      @param _preferUnstakedTokens Whether ERC20's should be redeemed first if they have been issued.

      @return fundingCycle The funding cycle during which the redemption was made.
      @return claimAmount The amount claimed.
      @return memo A memo that should be passed along to the emitted event.
    */
    function recordRedemption(
        address _holder,
        uint256 _projectId,
        uint256 _tokenCount,
        uint256 _minReturnedWei,
        address payable _beneficiary,
        string calldata _memo,
        bool _preferUnstakedTokens
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
        // The holder must have the specified number of the project's tokens.
        require(
            ticketBooth.balanceOf(_holder, _projectId) >= _tokenCount,
            "TV2DL: INSUFFICIENT_TOKENS"
        );

        // Get a reference to the project's current funding cycle.
        fundingCycle = fundingCycles.currentOf(_projectId);

        // The current funding cycle must not be paused.
        require(fundingCycle.redeemPaused(), "TV2DL: PAUSED");

        // Save a reference to the delegate to use.
        IRedeemDelegate _delegate;

        // If the funding cycle has configured a data source, use it to derive a claim amount and memo.
        if (fundingCycle.useDataSourceForRedeem()) {
            (claimAmount, memo, _delegate) = fundingCycle
                .dataSource()
                .redeemData(_holder, _tokenCount, _beneficiary, _memo);
        } else {
            claimAmount = _claimableOverflowOf(fundingCycle, _tokenCount);
            memo = _memo;
        }

        // The amount being claimed must be at least as much as was expected.
        require(claimAmount >= _minReturnedWei, "TV2DL: INADEQUATE");

        // The amount being claimed must be within the project's balance.
        require(
            claimAmount <= balanceOf[_projectId],
            "TV2DL: INSUFFICIENT_FUNDS"
        );

        // Redeem the tokens, which burns them.
        if (_tokenCount > 0) {
            // Update the token tracker so that reserved tokens will still be correctly mintable.
            _subtractFromTokenTracker(_projectId, _tokenCount);
            ticketBooth.redeem(
                _holder,
                _projectId,
                _tokenCount,
                _preferUnstakedTokens
            );
        }

        // Remove the redeemed funds from the project's balance.
        if (claimAmount > 0)
            balanceOf[_projectId] = balanceOf[_projectId] - claimAmount;

        // If a delegate was returned by the data source, issue a callback to it.
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

    /**
      @notice
      Allows a project owner to migrate its funds and treasury operations to a new contract.

      @dev
      Only the payment layer can record migrations.

      @param _projectId The ID of the project being migrated.
      @param _to The contract that will gain the project's funds.
    */
    function recordMigration(uint256 _projectId, ITerminal _to)
        external
        override
        onlyPaymentLayer
        returns (uint256 balance)
    {
        // The migration destination must be allowed.
        require(migrationIsAllowed[_to], "TV2DL: NOT_ALLOWED");

        // All reserved tokens must be minted before migrating.
        if (
            uint256(_processedTokenTrackerOf[_projectId]) !=
            ticketBooth.totalSupplyOf(_projectId)
        ) _distributeReservedTokens(_projectId, "");

        // Get a reference to the project's currently recorded balance.
        balance = balanceOf[_projectId];

        // Set the balance to 0.
        balanceOf[_projectId] = 0;

        // Switch the terminal that the terminal directory will point to for this project.
        terminalDirectory.setTerminal(_projectId, _to);
    }

    /**
      @notice
      Records newly added funds for the project made at the payment layer.

      @dev
      Only the payment layer can record added balance.

      @param _amount The amount added, in wei.
      @param _projectId The ID of the project to which the funds being added belong.
    */
    function recordAddedBalance(uint256 _amount, uint256 _projectId)
        external
        override
        onlyPaymentLayer
    {
        // Set the balance.
        balanceOf[_projectId] = balanceOf[_projectId] + _amount;
    }

    //*********************************************************************//
    // --------- external transactions only accessable by owner ---------- //
    //*********************************************************************//

    /**
      @notice
      Adds a Terminal address to the allow list that project owners can migrate its funds and treasury operations to.

      @dev
      Only this contract's owner can add a contract to the migration allow list.

      @param _terminal The terminal contract to allow.
    */
    function allowMigration(ITerminal _terminal) external override onlyOwner {
        // Toggle the contract as allowed.
        migrationIsAllowed[_terminal] = !migrationIsAllowed[_terminal];

        emit AllowMigration(_terminal);
    }

    /**
      @notice
      Sets the contract that is operating as this contract's payment layer.

      @dev
      Only this contract's owner can set this contract's payment layer.

      @param _paymentLayer The payment layer contract to set.
    */
    function setPaymentLayer(ITerminalV2PaymentLayer _paymentLayer)
        external
        override
        onlyOwner
    {
        // Set the contract.
        paymentLayer = _paymentLayer;

        emit SetPaymentLayer(_paymentLayer, msg.sender);
    }

    //*********************************************************************//
    // --- external transactions that relay funds to the payment layer --- //
    //*********************************************************************//

    /**
      @notice
      This call forwards all ETH received to the payment layer and does not modify state.

      @param _projectId The ID of the project being contribute to.
      @param _beneficiary The address to mint tokens for.
      @param _memo A memo that will be included in the published event.
      @param _preferUnstakedTokens Whether tokens should be unstaked automatically if ERC20's have been issued.

      @return The number of the funding cycle that the payment was made during.
    */
    function pay(
        uint256 _projectId,
        address _beneficiary,
        string calldata _memo,
        bool _preferUnstakedTokens
    ) external payable override returns (uint256) {
        // The payment layer should never make a call to this function.
        require(msg.sender != address(paymentLayer), "TV2DL: FORBIDDEN");

        // This contract should forward the parameters and all ETH received to the payment layer.
        return
            paymentLayer.pay{value: msg.value}(
                _projectId,
                _beneficiary,
                0,
                _memo,
                _preferUnstakedTokens
            );
    }

    /**
      @notice
      This call forwards all ETH received to the payment layer and does not modify state.

      @param _projectId The ID of the project being funded.
    */
    function addToBalance(uint256 _projectId) external payable override {
        require(msg.sender != address(paymentLayer), "TV2DL: FORBIDDEN");
        // This contract should forward the parameters and all ETH received to the payment layer.
        paymentLayer.addToBalance{value: msg.value}(_projectId);
    }

    //*********************************************************************//
    // --------------------- private helper functions -------------------- //
    //*********************************************************************//

    /**
      @notice
      Validate and pack the funding cycle metadata.

      @param _metadata The metadata to validate and pack.

      @return packed The packed uint256 of all metadata params. The first 8 bytes specify the version.
     */
    function _validateAndPackFundingCycleMetadata(
        FundingCycleMetadataV2 memory _metadata
    ) private pure returns (uint256 packed) {
        // The reserved project token rate must be less than or equal to 200.
        require(_metadata.reservedRate <= 200, "TV2DL: BAD_RESERVED_RATE");

        // The redemption rate must be between 0 and 200.
        require(_metadata.redemptionRate <= 200, "TV2DL: BAD_REDEMPTION_RATE");

        // The ballot redemption rate must be less than or equal to 200.
        require(
            _metadata.ballotRedemptionRate <= 200,
            "TV2DL: BAD_BALLOT_REDEMPTION_RATE"
        );

        // version 1 in the first 8 bytes.
        packed = 1;
        // reserved rate in bits 8-15.
        packed |= _metadata.reservedRate << 8;
        // bonding curve in bits 16-23.
        packed |= _metadata.redemptionRate << 16;
        // reconfiguration bonding curve rate in bits 24-31.
        packed |= _metadata.ballotRedemptionRate << 24;
        // pause pay in bit 32.
        packed |= (_metadata.pausePay ? 1 : 0) << 32;
        // pause tap in bit 33.
        packed |= (_metadata.pauseWithdraw ? 1 : 0) << 33;
        // pause redeem in bit 34.
        packed |= (_metadata.pauseRedeem ? 1 : 0) << 34;
        // pause mint in bit 35.
        packed |= (_metadata.pauseMint ? 1 : 0) << 35;
        // pause mint in bit 36.
        packed |= (_metadata.pauseBurn ? 1 : 0) << 36;
        // use pay data source in bit 37.
        packed |= (_metadata.useDataSourceForPay ? 1 : 0) << 37;
        // use redeem data source in bit 38.
        packed |= (_metadata.useDataSourceForRedeem ? 1 : 0) << 38;
        // data source address in bits 39-198.
        packed |= uint160(address(_metadata.dataSource)) << 39;
    }

    /**
      @notice 
      See docs for `distributeReservedTokens`
    */
    function _distributeReservedTokens(uint256 _projectId, string memory _memo)
        private
        returns (uint256 count)
    {
        // Get the current funding cycle to read the reserved rate from.
        FundingCycle memory _fundingCycle = fundingCycles.currentOf(_projectId);

        // There aren't any reserved tokens to mint and distribute if there is no funding cycle.
        if (_fundingCycle.number == 0) return 0;

        // Get a reference to new total supply of tokens before minting reserved tokens.
        uint256 _totalTokens = ticketBooth.totalSupplyOf(_projectId);

        // Get a reference to the number of tokens that need to be minted.
        count = _reservedTokenAmountFrom(
            _processedTokenTrackerOf[_projectId],
            _fundingCycle.reservedRate(),
            _totalTokens
        );

        // Set the tracker to be the new total supply.
        _processedTokenTrackerOf[_projectId] = int256(_totalTokens + count);

        // Get a reference to the project owner.
        address _owner = projects.ownerOf(_projectId);

        // Distribute tokens to splits and get a reference to the leftover amount to mint after all splits have gotten their share.
        uint256 _leftoverTokenCount = count == 0
            ? 0
            : _distributeToReservedTokenSplits(_fundingCycle, count);

        // Mint any leftover tokens to the project owner.
        if (_leftoverTokenCount > 0)
            ticketBooth.print(_owner, _projectId, _leftoverTokenCount, false);

        emit DistributeReservedTokens(
            _fundingCycle.number,
            _projectId,
            _owner,
            count,
            _leftoverTokenCount,
            _memo,
            msg.sender
        );
    }

    /**
      @notice
      See docs for `claimableOverflowOf`
     */
    function _claimableOverflowOf(
        FundingCycle memory _fundingCycle,
        uint256 _tokenCount
    ) private view returns (uint256) {
        // Get the amount of current overflow.
        uint256 _currentOverflow = _overflowFrom(_fundingCycle);

        // If there is no overflow, nothing is claimable.
        if (_currentOverflow == 0) return 0;

        // Get the total number of tokens in circulation.
        uint256 _totalSupply = ticketBooth.totalSupplyOf(
            _fundingCycle.projectId
        );

        // Get the number of reserved tokens the project has.
        uint256 _reservedTokenAmount = _reservedTokenAmountFrom(
            _processedTokenTrackerOf[_fundingCycle.projectId],
            _fundingCycle.reservedRate(),
            _totalSupply
        );

        // If there are reserved tokens, add them to the total supply.
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
      Gets the amount that is overflowing if measured from the specified funding cycle.

      @dev
      This amount changes as the price of ETH changes in relation to the funding cycle's currency.

      @param _fundingCycle The ID of the funding cycle to base the overflow on.

      @return overflow The overflow of funds.
    */
    function _overflowFrom(FundingCycle memory _fundingCycle)
        private
        view
        returns (uint256)
    {
        // Get the current balance of the project.
        uint256 _balanceOf = balanceOf[_fundingCycle.projectId];

        // If there's no balance, there's no overflow.
        if (_balanceOf == 0) return 0;

        // Get a reference to the amount still withdrawable during the funding cycle.
        uint256 _limit = _fundingCycle.target - _fundingCycle.tapped;

        // Convert the limit to ETH.
        uint256 _ethLimit = _limit == 0
            ? 0 // Get the current price of ETH.
            : PRBMathUD60x18.div(
                _limit,
                prices.getETHPriceFor(_fundingCycle.currency)
            );

        // Overflow is the balance of this project minus the amount that can still be withdrawn.
        return _balanceOf < _ethLimit ? 0 : _balanceOf - _ethLimit;
    }

    /**
      @notice
      Distributed tokens to the splits according to the specified funding cycle configuration.

      @param _fundingCycle The funding cycle to base the token distribution on.
      @param _amount The total amount of tokens to mint.

      @return leftoverAmount If the splits percents dont add up to 100%, the leftover amount is returned.
    */
    function _distributeToReservedTokenSplits(
        FundingCycle memory _fundingCycle,
        uint256 _amount
    ) private returns (uint256 leftoverAmount) {
        // Set the leftover amount to the initial amount.
        leftoverAmount = _amount;

        // Get a reference to the project's reserved token splits.
        Split[] memory _splits = splitsStore.get(
            _fundingCycle.projectId,
            _fundingCycle.configured,
            SplitsGroups.ReservedTokens
        );

        //Transfer between all splits.
        for (uint256 _i = 0; _i < _splits.length; _i++) {
            // Get a reference to the split being iterated on.
            Split memory _split = _splits[_i];

            // The amount to send towards the split. Split percents are out of 10000.
            uint256 _tokenCount = PRBMath.mulDiv(
                _amount,
                _split.percent,
                10000
            );

            // Mints tokens for the split if needed.
            if (_tokenCount > 0)
                ticketBooth.print(
                    // If a projectId is set in the split, set the project's owner as the beneficiary.
                    // Otherwise use the split's beneficiary.
                    _split.projectId != 0
                        ? projects.ownerOf(_split.projectId)
                        : _split.beneficiary,
                    _fundingCycle.projectId,
                    _tokenCount,
                    _split.preferUnstaked
                );

            // If there's an allocator set, trigger its `allocate` function.
            if (_split.allocator != ISplitAllocator(address(0)))
                _split.allocator.allocate(
                    _tokenCount,
                    _fundingCycle.projectId,
                    _split.projectId,
                    _split.beneficiary,
                    _split.preferUnstaked
                );

            // Subtract from the amount to be sent to the beneficiary.
            leftoverAmount = leftoverAmount - _tokenCount;

            emit DistributeToReservedTokenSplit(
                _fundingCycle.number,
                _fundingCycle.id,
                _fundingCycle.projectId,
                _split,
                _tokenCount,
                msg.sender
            );
        }
    }

    /** 
      @notice
      Subtracts the provided value from the processed token tracker.

      @dev
      Necessary to account for both positive and negative values.

      @param _projectId The ID of the project that is having its tracker subtracted from.
      @param _amount The amount to subtract.

    */
    function _subtractFromTokenTracker(uint256 _projectId, uint256 _amount)
        private
    {
        // Get a reference to the processed token tracker for the project.
        int256 _processedTokenTracker = _processedTokenTrackerOf[_projectId];

        // Subtract the count from the processed token tracker.
        // If there are at least as many processed tokens as the specified amount,
        // the processed token tracker of the project will be positive. Otherwise it will be negative.
        _processedTokenTrackerOf[_projectId] = _processedTokenTracker < 0 // If the tracker is negative, add the count and reverse it.
            ? -int256(uint256(-_processedTokenTracker) + _amount) // the tracker is less than the count, subtract it from the count and reverse it.
            : _processedTokenTracker < int256(_amount)
            ? -(int256(_amount) - _processedTokenTracker) // simply subtract otherwise.
            : _processedTokenTracker - int256(_amount);
    }

    /**
      @notice
      Gets the amount of reserved tokens currently tracked for a project given a reserved rate.

      @param _processedTokenTracker The tracker to make the calculation with.
      @param _reservedRate The reserved rate to use to make the calculation.
      @param _totalEligibleTokens The total amount to make the calculation with.

      @return amount reserved token amount.
    */
    function _reservedTokenAmountFrom(
        int256 _processedTokenTracker,
        uint256 _reservedRate,
        uint256 _totalEligibleTokens
    ) private pure returns (uint256) {
        // Get a reference to the amount of tokens that are unprocessed.
        uint256 _unprocessedTokenBalanceOf = _processedTokenTracker >= 0 // preconfigure tokens shouldn't contribute to the reserved token amount.
            ? _totalEligibleTokens - uint256(_processedTokenTracker)
            : _totalEligibleTokens + uint256(-_processedTokenTracker);

        // If there are no unprocessed tokens, return.
        if (_unprocessedTokenBalanceOf == 0) return 0;

        // If all tokens are reserved, return the full unprocessed amount.
        if (_reservedRate == 200) return _unprocessedTokenBalanceOf;

        return
            PRBMath.mulDiv(
                _unprocessedTokenBalanceOf,
                200,
                200 - _reservedRate
            ) - _unprocessedTokenBalanceOf;
    }

    /** 
      @notice 
      Configures a funding cycle and stores information pertinent to the configuration.

      @dev
      See the docs for `launchProject` and `configureFundingCycles`.
    */
    function _configure(
        uint256 _projectId,
        FundingCycleProperties calldata _properties,
        uint256 _packedMetadata,
        uint256 _overflowAllowance,
        Split[] memory _payoutSplits,
        Split[] memory _reservedTokenSplits,
        bool _shouldConfigureActive
    ) private returns (uint256) {
        // Configure the funding cycle's properties.
        FundingCycle memory _fundingCycle = fundingCycles.configure(
            _projectId,
            _properties,
            _packedMetadata,
            fee,
            _shouldConfigureActive
        );

        // Set payout splits if there are any.
        if (_payoutSplits.length > 0)
            splitsStore.set(
                _projectId,
                _fundingCycle.configured,
                SplitsGroups.Payouts,
                _payoutSplits
            );

        // Set token splits if there are any.
        if (_reservedTokenSplits.length > 0)
            splitsStore.set(
                _projectId,
                _fundingCycle.configured,
                SplitsGroups.ReservedTokens,
                _reservedTokenSplits
            );

        // Set the overflow allowance if the value is different from the currently set value.
        if (
            _overflowAllowance !=
            overflowAllowanceOf[_projectId][_fundingCycle.configured]
        ) {
            overflowAllowanceOf[_projectId][
                _fundingCycle.configured
            ] = _overflowAllowance;

            emit SetOverflowAllowance(
                _projectId,
                _fundingCycle.configured,
                _overflowAllowance,
                msg.sender
            );
        }

        return _fundingCycle.id;
    }
}
