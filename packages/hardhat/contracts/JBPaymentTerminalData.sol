// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@paulrberg/contracts/math/PRBMath.sol";
import "@paulrberg/contracts/math/PRBMathUD60x18.sol";

import "./libraries/Operations.sol";
import "./libraries/Operations2.sol";
import "./libraries/FundingCycleMetadataResolver.sol";

// Inheritance
import "./interfaces/IJBPaymentTerminalData.sol";
import "./abstract/JBOperatable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./JBController.sol";

/**
  @notice 
  This contract stitches together funding cycles and treasury tokens. It makes sure all activity is accounted for and correct. 

  @dev 
  Each project can only have one terminal registered at a time with the JBDirectory. This is how the outside world knows where to send money when trying to pay a project.
  The project's currently set terminal is the only contract that can interact with the FundingCycles and TicketBooth contracts on behalf of the project.

  The project's currently set terminal is also the contract that will receive payments by default when the outside world references directly from the JBDirectory.
  Since this contract doesn't deal with money directly, it will immedeiately forward payments to appropriate functions in the payment layer if it receives external calls via ITerminal methods `pay` or `addToBalance`.
  
  Inherits from:

  IJBPaymentTerminalData - general interface for the methods in this contract that change the blockchain's state according to the Juicebox protocol's rules.
  JBOperatable - several functions in this contract can only be accessed by a project owner, or an address that has been preconfifigured to be an operator of the project.
  Ownable - the owner of this contract can specify its payment layer contract, and add new ITerminals to an allow list that projects currently using this terminal can migrate to.
  ReentrencyGuard - several function in this contract shouldn't be accessible recursively.
*/
contract JBPaymentTerminalData is
    IJBPaymentTerminalData,
    JBOperatable,
    Ownable,
    ReentrancyGuard
{
    // A library that parses the packed funding cycle metadata into a more friendly format.
    using FundingCycleMetadataResolver for FundingCycle;

    // Modifier to only allow the payment layer to call the function.
    modifier onlyPaymentTerminal() {
        require(
            msg.sender == address(paymentTerminal),
            "JBPaymentTerminalData: UNAUTHORIZED"
        );
        _;
    }

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /** 
      @notice 
      The contract storing all funding cycle configurations.
    */
    IJBFundingCycleStore public immutable override fundingCycleStore;

    /** 
      @notice 
      The contract that manages token minting and burning.
    */
    IJBTokenStore public immutable override tokenStore;

    /** 
      @notice 
      The contract that exposes price feeds.
    */
    IJBPrices public immutable override prices;

    /** 
      @notice 
      The directory of terminals.
    */
    IJBDirectory public immutable override directory;

    IJBController public immutable override jb;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /** 
      @notice 
      The amount of ETH that each project has.

      @dev
      [_projectId] 

      _projectId The ID of the project to get the balance of.

      @return The ETH balance of the specified project.
    */
    mapping(uint256 => uint256) public override balanceOf;

    /**
      @notice 
      The amount of overflow that a project is allowed to tap into on-demand.

      @dev
      [_projectId][_configuration]

      _projectId The ID of the project to get the current overflow allowance of.
      _configuration The configuration of the during which the allowance applies.

      @return The current overflow allowance for the specified project configuration. Decreases as projects use of the allowance.
    */
    mapping(uint256 => mapping(uint256 => uint256))
        public
        override usedOverflowAllowanceOf;

    /** 
      @notice 
      The contract that stores funds, and manages inflows/outflows.
    */
    IJBTerminal public override paymentTerminal;

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
        FundingCycle memory _fundingCycle = fundingCycleStore.currentOf(
            _projectId
        );

        // There's no overflow if there's no funding cycle.
        if (_fundingCycle.number == 0) return 0;

        return _overflowFrom(_fundingCycle);
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
                fundingCycleStore.currentOf(_projectId),
                _tokenCount
            );
    }

    //*********************************************************************//
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /**
      @param _jb asdf.
      @param _operatorStore A contract storing operator assignments.
      @param _fundingCycleStore The contract storing all funding cycle configurations.
      @param _tokenStore The contract that manages token minting and burning.
      @param _prices The contract that exposes price feeds.
      @param _directory The directory of terminals.
    */
    constructor(
        IJBController _jb,
        IJBOperatorStore _operatorStore,
        IJBFundingCycleStore _fundingCycleStore,
        IJBTokenStore _tokenStore,
        IJBPrices _prices,
        IJBDirectory _directory
    ) JBOperatable(_operatorStore) {
        jb = _jb;
        fundingCycleStore = _fundingCycleStore;
        tokenStore = _tokenStore;
        prices = _prices;
        directory = _directory;
    }

    //*********************************************************************//
    // --------------------- external transactions ----------------------- //
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
      @param _preferUnstakedTokensAndBeneficiary Two properties are included in this packed uint256:
        The first bit contains the flag indicating whether the request prefers to issue tokens unstaked rather than staked.
        The remaining bits contains the address that should receive benefits from the payment.

        This design is necessary two prevent a "Stack too deep" compiler error that comes up if the variables are declared seperately.
      @param _minReturnedTokens The minimum number of tokens expected in return.
      @param _memo A memo that will be included in the published event.
      @param _delegateMetadata Bytes to send along to the delegate, if one is provided.

      @return fundingCycle The funding cycle during which payment was made.
      @return weight The weight according to which new token supply was minted.
      @return tokenCount The number of tokens that were minted.
      @return memo A memo that should be included in the published event.
    */
    function recordPaymentFrom(
        address _payer,
        uint256 _amount,
        uint256 _projectId,
        uint256 _preferUnstakedTokensAndBeneficiary,
        uint256 _minReturnedTokens,
        string memory _memo,
        bytes memory _delegateMetadata
    )
        public
        override
        onlyPaymentTerminal
        returns (
            FundingCycle memory fundingCycle,
            uint256 weight,
            uint256 tokenCount,
            string memory memo
        )
    {
        // Get a reference to the current funding cycle for the project.
        fundingCycle = fundingCycleStore.currentOf(_projectId);

        // The project must have a funding cycle configured.
        require(
            fundingCycle.number > 0,
            "JBPaymentTerminalData::recordPaymentFrom: NOT_FOUND"
        );

        // Must not be paused.
        require(
            !fundingCycle.payPaused(),
            "JBPaymentTerminalData::recordPaymentFrom: PAUSED"
        );

        // Save a reference to the delegate to use.
        IJBPayDelegate _delegate;

        // If the funding cycle has configured a data source, use it to derive a weight and memo.
        if (fundingCycle.useDataSourceForPay()) {
            (weight, memo, _delegate, _delegateMetadata) = fundingCycle
                .dataSource()
                .payData(
                    PayDataParam(
                        _payer,
                        _amount,
                        fundingCycle.weight,
                        fundingCycle.reservedRate(),
                        address(
                            uint160(_preferUnstakedTokensAndBeneficiary >> 1)
                        ),
                        _memo,
                        _delegateMetadata
                    )
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
            require(
                tokenCount >= _minReturnedTokens,
                "JBPaymentTerminalData::recordPaymentFrom: INADEQUATE"
            );

            // Add the amount to the balance of the project.
            balanceOf[_projectId] = balanceOf[_projectId] + _amount;

            if (_weightedAmount > 0)
                jb.mintTokensOf(
                    _projectId,
                    tokenCount,
                    address(uint160(_preferUnstakedTokensAndBeneficiary >> 1)),
                    "ETH received",
                    (_preferUnstakedTokensAndBeneficiary & 1) == 0,
                    true
                );
        }

        // If a delegate was returned by the data source, issue a callback to it.
        // TODO: see if we can made didPay easier and safer for people automatically.
        // TODO: wording. subscriber? "Delegate" might overload some ethereum specific terminology.
        // TODO: should delegates be an array?
        if (_delegate != IJBPayDelegate(address(0))) {
            DidPayParam memory _param = DidPayParam(
                _payer,
                _projectId,
                _amount,
                weight,
                tokenCount,
                payable(
                    address(uint160(_preferUnstakedTokensAndBeneficiary >> 1))
                ),
                memo,
                _delegateMetadata
            );
            _delegate.didPay(_param);
            emit DelegateDidPay(_delegate, _param);
        }
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
    function recordWithdrawalFor(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei
    )
        external
        override
        onlyPaymentTerminal
        returns (FundingCycle memory fundingCycle, uint256 withdrawnAmount)
    {
        // Registers the funds as withdrawn and gets the ID of the funding cycle during which this withdrawal is being made.
        fundingCycle = jb.withdrawFrom(_projectId, _amount);

        // Funds cannot be withdrawn if there's no funding cycle.
        require(
            fundingCycle.id > 0,
            "JBPaymentTerminalData::recordWithdrawalFor: NOT_FOUND"
        );

        // The funding cycle must not be paused.
        require(
            !fundingCycle.tapPaused(),
            "JBPaymentTerminalData::recordWithdrawalFor: PAUSED"
        );

        // Make sure the currencies match.
        require(
            _currency == fundingCycle.currency,
            "JBPaymentTerminalData::recordWithdrawalFor: UNEXPECTED_CURRENCY"
        );

        // Convert the amount to wei.
        withdrawnAmount = PRBMathUD60x18.div(
            _amount,
            prices.getETHPriceFor(fundingCycle.currency)
        );

        // The amount being withdrawn must be at least as much as was expected.
        require(
            _minReturnedWei <= withdrawnAmount,
            "JBPaymentTerminalData::recordWithdrawalFor: INADEQUATE"
        );

        // The amount being withdrawn must be available.
        require(
            withdrawnAmount <= balanceOf[_projectId],
            "JBPaymentTerminalData::recordWithdrawalFor: INSUFFICIENT_FUNDS"
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
    function recordUsedAllowanceOf(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei
    )
        external
        override
        onlyPaymentTerminal
        returns (FundingCycle memory fundingCycle, uint256 withdrawnAmount)
    {
        // Get a reference to the project's current funding cycle.
        fundingCycle = fundingCycleStore.currentOf(_projectId);

        // Make sure the currencies match.
        require(
            _currency == fundingCycle.currency,
            "JBPaymentTerminalData::recordUsedAllowanceOf: UNEXPECTED_CURRENCY"
        );

        // Convert the amount to wei.
        withdrawnAmount = PRBMathUD60x18.div(
            _amount,
            prices.getETHPriceFor(fundingCycle.currency)
        );

        // There must be sufficient allowance available.
        require(
            withdrawnAmount <=
                jb.overflowAllowanceOf(_projectId, fundingCycle.configured) -
                    usedOverflowAllowanceOf[_projectId][
                        fundingCycle.configured
                    ],
            "JBPaymentTerminalData::recordUsedAllowanceOf: NOT_ALLOWED"
        );

        // The amount being withdrawn must be at least as much as was expected.
        require(
            _minReturnedWei <= withdrawnAmount,
            "JBPaymentTerminalData::recordUsedAllowanceOf: INADEQUATE"
        );

        // The amount being withdrawn must be available.
        require(
            withdrawnAmount <= balanceOf[_projectId],
            "JBPaymentTerminalData::recordUsedAllowanceOf: INSUFFICIENT_FUNDS"
        );

        // Store the decremented value.
        usedOverflowAllowanceOf[_projectId][fundingCycle.configured] =
            usedOverflowAllowanceOf[_projectId][fundingCycle.configured] +
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
      @param _beneficiary The address that will benefit from the claimed amount.
      @param _memo A memo to pass along to the emitted event.
      @param _delegateMetadata Bytes to send along to the delegate, if one is provided.

      @return fundingCycle The funding cycle during which the redemption was made.
      @return claimAmount The amount claimed.
      @return memo A memo that should be passed along to the emitted event.
    */
    function recordRedemptionFor(
        address _holder,
        uint256 _projectId,
        uint256 _tokenCount,
        uint256 _minReturnedWei,
        address payable _beneficiary,
        string memory _memo,
        bytes memory _delegateMetadata
    )
        external
        override
        onlyPaymentTerminal
        returns (
            FundingCycle memory fundingCycle,
            uint256 claimAmount,
            string memory memo
        )
    {
        // The holder must have the specified number of the project's tokens.
        require(
            tokenStore.balanceOf(_holder, _projectId) >= _tokenCount,
            "JBPaymentTerminalData::recordRedemptionFor: INSUFFICIENT_TOKENS"
        );

        // Get a reference to the project's current funding cycle.
        fundingCycle = fundingCycleStore.currentOf(_projectId);

        // The current funding cycle must not be paused.
        require(
            !fundingCycle.redeemPaused(),
            "JBPaymentTerminalData::recordRedemptionFor: PAUSED"
        );

        // Save a reference to the delegate to use.
        IJBRedemptionDelegate _delegate;

        // If the funding cycle has configured a data source, use it to derive a claim amount and memo.
        // TODO: think about using a default data source for default values.
        if (fundingCycle.useDataSourceForRedeem()) {
            (claimAmount, memo, _delegate, _delegateMetadata) = fundingCycle
                .dataSource()
                .redeemData(
                    RedeemDataParam(
                        _holder,
                        _tokenCount,
                        fundingCycle.redemptionRate(),
                        fundingCycle.ballotRedemptionRate(),
                        _beneficiary,
                        _memo,
                        _delegateMetadata
                    )
                );
        } else {
            claimAmount = _claimableOverflowOf(fundingCycle, _tokenCount);
            memo = _memo;
        }

        // The amount being claimed must be at least as much as was expected.
        require(
            claimAmount >= _minReturnedWei,
            "JBPaymentTerminalData::recordRedemptionFor: INADEQUATE"
        );

        // The amount being claimed must be within the project's balance.
        require(
            claimAmount <= balanceOf[_projectId],
            "JBPaymentTerminalData::recordRedemptionFor: INSUFFICIENT_FUNDS"
        );

        // Redeem the tokens, which burns them.
        if (_tokenCount > 0)
            jb.burnTokensOf(
                _holder,
                _projectId,
                _tokenCount,
                "Redeem for ETH",
                true
            );

        // Remove the redeemed funds from the project's balance.
        if (claimAmount > 0)
            balanceOf[_projectId] = balanceOf[_projectId] - claimAmount;

        // If a delegate was returned by the data source, issue a callback to it.
        if (_delegate != IJBRedemptionDelegate(address(0))) {
            DidRedeemParam memory _param = DidRedeemParam(
                _holder,
                _projectId,
                _tokenCount,
                claimAmount,
                _beneficiary,
                memo,
                _delegateMetadata
            );
            _delegate.didRedeem(_param);
            emit DelegateDidRedeem(_delegate, _param);
        }
    }

    /**
      @notice
      Allows a project owner to transfer its balance and treasury operations to a new contract.

      @dev
      Only the payment layer can record balance transfers.

      @param _projectId The ID of the project having its balance transfered.
      @param _terminal The terminal that the balance is being transfered to.
    */
    function recordBalanceTransferFor(uint256 _projectId, IJBTerminal _terminal)
        external
        override
        onlyPaymentTerminal
        returns (uint256 balance)
    {
        // Get a reference to the project's currently recorded balance.
        balance = balanceOf[_projectId];

        // Set the balance to 0.
        balanceOf[_projectId] = 0;

        // Switch the terminal that the directory will point to for this project.
        directory.setTerminalOf(_projectId, _terminal);
    }

    /**
      @notice
      Records newly added funds for the project made at the payment layer.

      @dev
      Only the payment layer can record added balance.

      @param _projectId The ID of the project to which the funds being added belong.
      @param _amount The amount added, in wei.
    */
    function recordAddedBalanceFor(uint256 _projectId, uint256 _amount)
        external
        override
        onlyPaymentTerminal
    {
        // Set the balance.
        balanceOf[_projectId] = balanceOf[_projectId] + _amount;
    }

    //*********************************************************************//
    // --------- external transactions only accessable by owner ---------- //
    //*********************************************************************//

    /**
      @notice
      Sets the contract that is operating as this contract's payment layer.

      @dev
      Only this contract's owner can set this contract's payment layer.

      @param _paymentTerminal The payment layer contract to set.
    */
    function setPaymentTerminalOf(IJBTerminal _paymentTerminal)
        external
        override
        onlyOwner
    {
        // Set the contract.
        paymentTerminal = _paymentTerminal;

        emit SetPaymentTerminal(_paymentTerminal, msg.sender);
    }

    //*********************************************************************//
    // --------------------- private helper functions -------------------- //
    //*********************************************************************//

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
        uint256 _totalSupply = tokenStore.totalSupplyOf(
            _fundingCycle.projectId
        );

        // Get the number of reserved tokens the project has.
        uint256 _reservedTokenAmount = jb.reservedTokenBalanceOf(
            _fundingCycle.projectId,
            _fundingCycle.reservedRate()
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
        uint256 _redemptionRate = fundingCycleStore.currentBallotStateOf(
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
}
