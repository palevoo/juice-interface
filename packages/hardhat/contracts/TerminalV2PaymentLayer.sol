// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/Address.sol";

import "@paulrberg/contracts/math/PRBMath.sol";

import "./abstract/JuiceboxProject.sol";

import "./libraries/Operations.sol";
import "./libraries/Operations2.sol";
import "./libraries/SplitsGroups.sol";

// Inheritance
import "./interfaces/ITerminalV2PaymentLayer.sol";
import "./abstract/Operatable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
  @notice 
  This contract manages all inflows and outflows of funds into the Juicebox ecosystem. It stores all treasury funds for all projects.

  @dev 
  A project can transfer its funds, along with the power to reconfigure and mint/burn their Tickets, from this contract to another allowed terminal contract at any time.

  Inherits from:

  ITerminalV2PaymentLayer - general interface for the methods in this contract that send and receive funds according to the Juicebox protocol's rules.
  Operatable - several functions in this contract can only be accessed by a project owner, or an address that has been preconfifigured to be an operator of the project.
  ReentrencyGuard - several function in this contract shouldn't be accessible recursively.
*/
contract TerminalV2PaymentLayer is
    ITerminalV2PaymentLayer,
    Operatable,
    ReentrancyGuard
{
    // --- public immutable stored properties --- //

    /// @notice The Projects contract which mints ERC-721's that represent project ownership and transfers.
    IProjects public immutable override projects;

    /// @notice The contract that stores splits for each project.
    ISplitsStore public immutable override splitsStore;

    /// @notice The directory of terminals.
    ITerminalDirectory public immutable override terminalDirectory;

    /// @notice The contract that stiches together funding cycles and treasury tokens.
    ITerminalV2DataLayer public immutable override dataLayer;

    // --- external transactions --- //

    /** 
      @param _operatorStore A contract storing operator assignments.
      @param _projects A Projects contract which mints ERC-721's that represent project ownership and transfers.
      @param _splitsStore The contract that stores splits for each project.
      @param _terminalDirectory The directory of terminals.
      @param _dataLayer The contract that stiches together funding cycles and treasury tokens.
    */
    constructor(
        IOperatorStore _operatorStore,
        IProjects _projects,
        ISplitsStore _splitsStore,
        ITerminalDirectory _terminalDirectory,
        ITerminalV2DataLayer _dataLayer
    ) Operatable(_operatorStore) {
        projects = _projects;
        splitsStore = _splitsStore;
        terminalDirectory = _terminalDirectory;
        dataLayer = _dataLayer;
    }

    /**
      @notice
      Contribute ETH to a project.

      @dev
      The msg.value is the amount of the contribution in wei.

      @param _projectId The ID of the project being contribute to.
      @param _beneficiary The address to mint tokens for and pass along to the funding cycle's data source and delegate.
      @param _minReturnedTokens The minimum number of tokens expected in return.
      @param _memo A memo that will be included in the published event, and passed along the the funding cycle's data source and delegate.
      @param _preferUnstakedTokens Whether tokens should be unstaked automatically if ERC20's have been issued.

      @return The number of the funding cycle that the payment was made during.
    */
    function pay(
        uint256 _projectId,
        address _beneficiary,
        uint256 _minReturnedTokens,
        string calldata _memo,
        bool _preferUnstakedTokens
    ) external payable override returns (uint256) {
        return
            _pay(
                msg.value,
                _projectId,
                _beneficiary,
                _minReturnedTokens,
                _memo,
                _preferUnstakedTokens
            );
    }

    /**
      @notice 
      Distributes payouts for a project according to the constraints of its current funding cycle.
      Payouts are sent to the preprogrammed splits. 

      @dev
      Anyone can distribute payouts on a project's behalf.

      @param _projectId The ID of the project having its payouts distributed.
      @param _amount The amount being distributed.
      @param _currency The expected currency of the amount being distributed. Must match the project's current funding cycle's currency.
      @param _minReturnedWei The minimum number of wei that the amount should be valued at.

      @return The ID of the funding cycle during which the distribution was made.
    */
    function distributePayouts(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei,
        string memory _memo
    ) external override nonReentrant returns (uint256) {
        // Record the withdrawal in the data layer.
        (
            FundingCycle memory _fundingCycle,
            uint256 _withdrawnAmount
        ) = dataLayer.recordWithdrawal(
                _projectId,
                _amount,
                _currency,
                _minReturnedWei
            );

        // Get a reference to the project owner, which will receive tokens from paying the platform fee
        // and receive any extra distributable funds not allocated to payout splits.
        address payable _projectOwner = payable(projects.ownerOf(_projectId));

        // Get a reference to the handle of the project paying the fee and sending payouts.
        bytes32 _handle = projects.handleOf(_projectId);

        // Take a fee from the _withdrawnAmount, if needed.
        // The project's owner will be the beneficiary of the resulting minted tokens from platform project.
        // The platform project's ID is 1.
        uint256 _feeAmount = _fundingCycle.fee == 0 || _projectId == 1
            ? 0
            : _takeFee(
                _withdrawnAmount,
                _fundingCycle.fee,
                _projectOwner,
                string(bytes.concat("Fee from @", _handle))
            );

        // Payout to splits and get a reference to the leftover transfer amount after all mods have been paid.
        // The net transfer amount is the withdrawn amount minus the fee.
        uint256 _leftoverTransferAmount = _distributeToPayoutSplits(
            _fundingCycle,
            _withdrawnAmount - _feeAmount,
            string(bytes.concat("Payout from @", _handle))
        );

        // Transfer any remaining balance to the project owner.
        if (_leftoverTransferAmount > 0)
            Address.sendValue(_projectOwner, _leftoverTransferAmount);

        emit DistributePayouts(
            _fundingCycle.id,
            _projectId,
            _projectOwner,
            _amount,
            _withdrawnAmount,
            _feeAmount,
            _leftoverTransferAmount,
            _memo,
            msg.sender
        );

        return _fundingCycle.id;
    }

    /**
      @notice Allows a project to send funds from its overflow up to the preconfigured allowance.
      @param _projectId The ID of the project to use the allowance of.
      @param _amount The amount of the allowance to use.
      @param _beneficiary The address to send the funds to.
    */
    function useAllowance(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei,
        address payable _beneficiary
    )
        external
        override
        nonReentrant
        requirePermission(
            projects.ownerOf(_projectId),
            _projectId,
            Operations2.UseAllowance
        )
    {
        // Record the use of the allowance in the data layer.
        (
            FundingCycle memory _fundingCycle,
            uint256 _withdrawnAmount
        ) = dataLayer.recordUsedAllowance(
                _projectId,
                _amount,
                _currency,
                _minReturnedWei
            );

        // Get a reference to the project owner, which will receive tokens from paying the platform fee
        // and receive any extra distributable funds not allocated to payout splits.
        address payable _projectOwner = payable(projects.ownerOf(_projectId));

        // Get a reference to the handle of the project paying the fee and sending payouts.
        bytes32 _handle = projects.handleOf(_projectId);

        // Take a fee from the _withdrawnAmount, if needed.
        // The project's owner will be the beneficiary of the resulting minted tokens from platform project.
        // The platform project's ID is 1.
        uint256 _feeAmount = _fundingCycle.fee == 0 || _projectId == 1
            ? 0
            : _takeFee(
                _withdrawnAmount,
                _fundingCycle.fee,
                _projectOwner,
                string(bytes.concat("Fee from @", _handle))
            );

        // The leftover amount once the fee has been taken.
        uint256 _leftoverTransferAmount = _withdrawnAmount - _feeAmount;

        // Transfer any remaining balance to the project owner.
        if (_leftoverTransferAmount > 0)
            // Send the funds to the beneficiary.
            Address.sendValue(_beneficiary, _leftoverTransferAmount);

        emit UseAllowance(
            _fundingCycle.number,
            _fundingCycle.configured,
            _projectId,
            _beneficiary,
            _withdrawnAmount,
            _feeAmount,
            _leftoverTransferAmount,
            msg.sender
        );
    }

    /**
      @notice
      Addresses can redeem their tokens to claim the project's overflowed ETH, or to trigger rules determined by the project's current funding cycle's data source.

      @dev
      Only a token's holder or a designated operator can redeem it.

      @param _holder The account to redeem tokens for.
      @param _projectId The ID of the project to which the tokens being redeemed belong.
      @param _tokenCount The number of tokens to redeem.
      @param _minReturnedWei The minimum amount of Wei expected in return.
      @param _beneficiary The address to send the ETH to. Send the address this contract to burn the count.
      @param _memo A memo to attach to the emitted event.
      @param _preferUnstaked If the preference is to redeem tokens that have been converted to ERC-20s.

      @return amount The amount of ETH that the tokens were redeemed for, in wei.
    */
    function redeemTokens(
        address _holder,
        uint256 _projectId,
        uint256 _tokenCount,
        uint256 _minReturnedWei,
        address payable _beneficiary,
        string memory _memo,
        bool _preferUnstaked
    )
        external
        override
        nonReentrant
        requirePermissionAllowingWildcardDomain(
            _holder,
            _projectId,
            Operations.Redeem
        )
        returns (uint256)
    {
        // Keep a reference to the funding cycles during which the redemption is being made.
        FundingCycle memory _fundingCycle;

        // Keep a reference to the amount being claimed.
        uint256 _claimAmount;

        // Record the redemption in the data layer.
        (_fundingCycle, _claimAmount, _memo) = dataLayer.recordRedemption(
            _holder,
            _projectId,
            _tokenCount,
            _minReturnedWei,
            _beneficiary,
            _memo,
            _preferUnstaked
        );

        // Can't send claimed funds to the zero address.
        require(_beneficiary != address(0), "TerminalV2::redeem: ZERO_ADDRESS");

        // Send the claimed funds to the beneficiary.
        if (_claimAmount > 0) Address.sendValue(_beneficiary, _claimAmount);

        emit Redeem(
            _holder,
            _projectId,
            _beneficiary,
            _tokenCount,
            _claimAmount,
            _memo,
            msg.sender
        );

        return _claimAmount;
    }

    /**
      @notice
      Allows a project owner to migrate its funds and operations to a new terminal.

      @dev
      Only a project's owner or a designated operator can migrate it.

      @param _projectId The ID of the project being migrated.
      @param _to The terminal contract that will gain the project's funds.
    */
    function migrate(uint256 _projectId, ITerminalDataLayer _to)
        external
        override
        nonReentrant
        requirePermission(
            projects.ownerOf(_projectId),
            _projectId,
            Operations.Migrate
        )
    {
        // Allow the terminal receiving the project's funds and operations to prepare for the migration.
        _to.prepForMigrationOf(_projectId);

        // Record the migration in the data layer.
        uint256 _balance = dataLayer.recordMigration(_projectId, _to);

        // Move the funds to the new contract if needed.
        if (_balance > 0) _to.addToBalance{value: _balance}(_projectId);

        emit Migrate(_projectId, _to, _balance, msg.sender);
    }

    /**
      @notice
      Receives and allocated funds belonging to the specified project.

      @param _projectId The ID of the project to which the funds received belong.
    */
    function addToBalance(uint256 _projectId) external payable override {
        // Record the added funds in the data later.
        dataLayer.recordAddedBalance(msg.value, _projectId);

        emit AddToBalance(_projectId, msg.value, msg.sender);
    }

    // --- private helper functions --- //

    /** 
      @notice
      Pays out the splits.

      @param _fundingCycle The funding cycle during which the distribution is being made.
      @param _amount The total amount being distributed.
      @param _memo A memo to send along with emitted distribution events.

      @return leftoverAmount If the split module percents dont add up to 100%, the leftover amount is returned.

    */
    function _distributeToPayoutSplits(
        FundingCycle memory _fundingCycle,
        uint256 _amount,
        string memory _memo
    ) private returns (uint256 leftoverAmount) {
        // Set the leftover amount to the initial amount.
        leftoverAmount = _amount;

        // Get a reference to the project's payout splits.
        Split[] memory _splits = splitsStore.get(
            _fundingCycle.projectId,
            _fundingCycle.configured,
            SplitsGroups.Payouts
        );

        // If there are no splits, return the full leftover amount.
        if (_splits.length == 0) return leftoverAmount;

        //Transfer between all splits.
        for (uint256 _i = 0; _i < _splits.length; _i++) {
            // Get a reference to the mod being iterated on.
            Split memory _split = _splits[_i];

            // The amount to send towards mods. Mods percents are out of 10000.
            uint256 _payoutAmount = PRBMath.mulDiv(
                _amount,
                _split.percent,
                10000
            );

            if (_payoutAmount > 0) {
                // Transfer ETH to the mod.
                // If there's an allocator set, transfer to its `allocate` function.
                if (_split.allocator != ISplitAllocator(address(0))) {
                    _split.allocator.allocate{value: _payoutAmount}(
                        _payoutAmount,
                        _fundingCycle.projectId,
                        _split.projectId,
                        _split.beneficiary,
                        _split.preferUnstaked
                    );
                } else if (_split.projectId != 0) {
                    // Otherwise, if a project is specified, make a payment to it.

                    // Get a reference to the Juicebox terminal being used.
                    ITerminal _terminal = terminalDirectory.terminalOf(
                        _split.projectId
                    );

                    // The project must have a terminal to send funds to.
                    require(
                        _terminal != ITerminal(address(0)),
                        "TerminalV2::_distributeToPayoutSplits: BAD_MOD"
                    );

                    // Save gas if this contract is being used as the terminal.
                    if (address(_terminal) == address(dataLayer)) {
                        _pay(
                            _payoutAmount,
                            _split.projectId,
                            _split.beneficiary,
                            0,
                            _memo,
                            _split.preferUnstaked
                        );
                    } else {
                        _terminal.pay{value: _payoutAmount}(
                            _split.projectId,
                            _split.beneficiary,
                            _memo,
                            _split.preferUnstaked
                        );
                    }
                } else {
                    // Otherwise, send the funds directly to the beneficiary.
                    Address.sendValue(_split.beneficiary, _payoutAmount);
                }

                // Subtract from the amount to be sent to the beneficiary.
                leftoverAmount = leftoverAmount - _payoutAmount;
            }

            emit DistributeToPayoutSplit(
                _fundingCycle.number,
                _fundingCycle.id,
                _fundingCycle.projectId,
                _split,
                _payoutAmount,
                msg.sender
            );
        }
    }

    /** 
      @notice 
      Takes a fee into the platform's project, which has an id of 1.

      @param _from The amount to take a fee from.
      @param _percent The percent fee to take. Out of 200.
      @param _beneficiary The address to print governance's tickets for.
      @param _memo A memo to send with the fee.

      @return feeAmount The amount of the fee taken.
    */
    function _takeFee(
        uint256 _from,
        uint256 _percent,
        address _beneficiary,
        string memory _memo
    ) private returns (uint256 feeAmount) {
        // The amount of ETH from the _tappedAmount to pay as a fee.
        feeAmount = _from - PRBMath.mulDiv(_from, 200, _percent + 200);

        // Nothing to do if there's no fee to take.
        if (feeAmount == 0) return 0;

        // Get the terminal for the JuiceboxDAO project.
        ITerminal _terminal = terminalDirectory.terminalOf(1);

        // When processing the admin fee, save gas if the admin is using this contract as its terminal.
        address(_terminal) == address(dataLayer) // Use the local pay call.
            ? _pay(feeAmount, 1, _beneficiary, 0, _memo, false) // Use the external pay call of the correct terminal.
            : _terminal.pay{value: feeAmount}(1, _beneficiary, _memo, false);
    }

    /**
      @notice
      See the documentation for 'pay'.
    */
    function _pay(
        uint256 _amount,
        uint256 _projectId,
        address _beneficiary,
        uint256 _minReturnedTokens,
        string memory _memo,
        bool _preferUnstakedTokens
    ) private returns (uint256) {
        // Positive payments only.
        require(_amount > 0, "TerminalV2::_pay: BAD_AMOUNT");

        // Cant send tickets to the zero address.
        require(_beneficiary != address(0), "TerminalV2::_pay: ZERO_ADDRESS");

        FundingCycle memory _fundingCycle;
        uint256 _weight;
        uint256 _tokenCount;

        // Record the payment in the data layer.
        (_fundingCycle, _weight, _tokenCount, _memo) = dataLayer.recordPayment(
            msg.sender,
            _amount,
            _projectId,
            _beneficiary,
            _minReturnedTokens,
            _memo,
            _preferUnstakedTokens
        );

        emit Pay(
            _fundingCycle.number,
            _projectId,
            _beneficiary,
            _fundingCycle.id,
            _amount,
            _weight,
            _tokenCount,
            _memo,
            msg.sender
        );

        return _fundingCycle.number;
    }
}
