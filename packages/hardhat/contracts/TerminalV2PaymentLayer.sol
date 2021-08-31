// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@paulrberg/contracts/math/PRBMath.sol";

import "./interfaces/ITerminalV2PaymentLayer.sol";

import "./abstract/JuiceboxProject.sol";
import "./abstract/Operatable.sol";

import "./libraries/Operations.sol";
import "./libraries/Operations2.sol";

/**
  @notice 
  This contract manages the Juicebox ecosystem, serves as a payment terminal, and custodies all funds.

  @dev 
  A project can transfer its funds, along with the power to reconfigure and mint/burn their Tickets, from this contract to another allowed terminal contract at any time.
*/
contract TerminalV2PaymentLayer is
    ITerminalV2PaymentLayer,
    Operatable,
    ReentrancyGuard
{
    // --- public immutable stored properties --- //

    /// @notice The Projects contract which mints ERC-721's that represent project ownership and transfers.
    IProjects public immutable override projects;

    /// @notice The contract that stores mods for each project.
    IModStore public immutable override modStore;

    /// @notice The directory of terminals.
    ITerminalDirectory public immutable override terminalDirectory;

    /// @notice The storage contract for this terminal.
    ITerminalV2DataLayer public immutable override dataLayer;

    // --- external transactions --- //

    /** 
      @param _projects A Projects contract which mints ERC-721's that represent project ownership and transfers.
      @param _operatorStore A contract storing operator assignments.
      @param _modStore A storage for a project's mods.
      @param _terminalDirectory A directory of a project's current Juicebox terminal to receive payments in.
    */
    constructor(
        IOperatorStore _operatorStore,
        IProjects _projects,
        IModStore _modStore,
        ITerminalDirectory _terminalDirectory,
        ITerminalV2DataLayer _dataLayer
    ) Operatable(_operatorStore) {
        projects = _projects;
        modStore = _modStore;
        terminalDirectory = _terminalDirectory;
        dataLayer = _dataLayer;
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
      @param _minReturnedTickets The minimum number of tickets expected in return.
      @param _memo A memo that will be included in the published event.
      @param _preferUnstakedTickets Whether ERC20's should be unstaked automatically if they have been issued.

      @return The number of the funding cycle that the payment was made during.
    */
    function pay(
        uint256 _projectId,
        address _beneficiary,
        uint256 _minReturnedTickets,
        string calldata _memo,
        bool _preferUnstakedTickets
    ) external payable override returns (uint256) {
        return
            _pay(
                msg.value,
                _projectId,
                _beneficiary,
                _minReturnedTickets,
                _memo,
                _preferUnstakedTickets
            );
    }

    /**
      @notice 
      Tap into funds that have been contributed to a project's current funding cycle.

      @dev
      Anyone can tap funds on a project's behalf.

      @param _projectId The ID of the project to which the funding cycle being tapped belongs.
      @param _amount The amount being tapped, in the funding cycle's currency.
      @param _currency The expected currency being tapped.
      @param _minReturnedWei The minimum number of wei that the amount should be valued at.

      @return The ID of the funding cycle that was tapped.
    */
    function distributePayouts(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei,
        string memory _memo
    ) external override nonReentrant returns (uint256) {
        (
            FundingCycle memory _fundingCycle,
            uint256 _withdrawnAmount
        ) = dataLayer.recordWithdrawal(
                _projectId,
                _amount,
                _currency,
                _minReturnedWei
            );

        // Get a reference to the project owner, which will receive the admin's tickets from paying the fee,
        // and receive any extra tapped funds not allocated to mods.
        address payable _projectOwner = payable(projects.ownerOf(_projectId));

        // Get a reference to the handle of the project paying the fee and sending payouts.
        bytes32 _handle = projects.handleOf(_projectId);

        // Take a fee from the _withdrawnAmount, if needed.
        // The project's owner will be the beneficiary of the resulting printed tickets from the governance project.
        uint256 _feeAmount = _fundingCycle.fee == 0 || _projectId == 1
            ? 0
            : _takeFee(
                _withdrawnAmount,
                _fundingCycle.fee,
                _projectOwner,
                string(bytes.concat("Fee from @", _handle))
            );

        // Payout to mods and get a reference to the leftover transfer amount after all mods have been paid.
        // The net transfer amount is the tapped amount minus the fee.
        uint256 _leftoverTransferAmount = _distributeToPayoutMods(
            _fundingCycle.id,
            _fundingCycle.configured,
            _projectId,
            _withdrawnAmount - _feeAmount,
            string(bytes.concat("Payout from @", _handle))
        );

        // Transfer any remaining balance to the beneficiary.
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
      @param _beneficiary The address to send the funds.
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
        (
            FundingCycle memory _fundingCycle,
            uint256 _withdrawnAmount
        ) = dataLayer.recordUsedAllowance(
                _projectId,
                _amount,
                _currency,
                _minReturnedWei
            );

        // Otherwise, send the funds directly to the beneficiary.
        Address.sendValue(_beneficiary, _withdrawnAmount);

        emit UseAllowance(
            _projectId,
            _fundingCycle.configured,
            _withdrawnAmount,
            _beneficiary,
            msg.sender
        );
    }

    // /**
    //   @notice
    //   Addresses can redeem their Tokens to claim the project's overflowed ETH.

    //   @dev
    //   Only a token's holder or a designated operator can redeem it.

    //   @param _holder The account to redeem tokens for.
    //   @param _projectId The ID of the project to which the tokens being redeemed belong.
    //   @param _tokenCount The number of tokens to redeem.
    //   @param _minReturnedWei The minimum amount of Wei expected in return.
    //   @param _beneficiary The address to send the ETH to. Send the address this contract to burn the count.
    //   @param _memo A memo to attach to the emitted event.
    //   @param _preferUnstaked If the preference is to redeem tokens that have been converted to ERC-20s.

    //   @return amount The amount of ETH that the tokens were redeemed for.
    // */
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
        FundingCycle memory _fundingCycle;
        uint256 _claimAmount;

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
        require(
            _claimAmount == 0 || _beneficiary != address(0),
            "TerminalV2::redeem: ZERO_ADDRESS"
        );

        // Remove the redeemed funds from the project's balance.
        if (_claimAmount > 0)
            // Transfer funds to the specified address.
            Address.sendValue(_beneficiary, _claimAmount);

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
      Allows a project owner to migrate its funds and operations to a new contract.

      @dev
      Only a project's owner or a designated operator can migrate it.

      @param _projectId The ID of the project being migrated.
      @param _to The contract that will gain the project's funds.
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
        _to.prepForMigrationOf(_projectId);

        uint256 _balance = dataLayer.recordMigration(_projectId, _to);

        // Move the funds to the new contract if needed.
        if (_balance > 0) _to.addToBalance{value: _balance}(_projectId);

        emit Migrate(_projectId, _to, _balance, msg.sender);
    }

    /**
      @notice
      Receives and allocates funds belonging to the specified project.

      @param _projectId The ID of the project to which the funds received belong.
    */
    function addToBalance(uint256 _projectId) external payable override {
        dataLayer.recordAddedBalance(msg.value, _projectId);
        emit AddToBalance(_projectId, msg.value, msg.sender);
    }

    // --- private helper functions --- //

    /** 
      @notice
      Pays out the mods for the specified funding cycle.

      @param _fundingCycleId The ID of the funding cycle to base the distribution on.
      @param _fundingCycleConfiguration The configuration of the funding cycle to base the distribution on.
      @param _amount The total amount being paid out.
      @param _memo A memo to send along with project payouts.

      @return leftoverAmount If the mod percents dont add up to 100%, the leftover amount is returned.

    */
    function _distributeToPayoutMods(
        uint256 _fundingCycleId,
        uint256 _fundingCycleConfiguration,
        uint256 _projectId,
        uint256 _amount,
        string memory _memo
    ) private returns (uint256 leftoverAmount) {
        // Set the leftover amount to the initial amount.
        leftoverAmount = _amount;

        // Get a reference to the project's payout mods.
        PayoutMod[] memory _mods = modStore.payoutModsOf(
            _projectId,
            _fundingCycleConfiguration
        );

        if (_mods.length == 0) return leftoverAmount;

        //Transfer between all mods.
        for (uint256 _i = 0; _i < _mods.length; _i++) {
            // Get a reference to the mod being iterated on.
            PayoutMod memory _mod = _mods[_i];

            // The amount to send towards mods. Mods percents are out of 10000.
            uint256 _modCut = PRBMath.mulDiv(_amount, _mod.percent, 10000);

            if (_modCut > 0) {
                // Transfer ETH to the mod.
                // If there's an allocator set, transfer to its `allocate` function.
                if (_mod.allocator != IModAllocator(address(0))) {
                    _mod.allocator.allocate{value: _modCut}(
                        _projectId,
                        _mod.projectId,
                        _mod.beneficiary
                    );
                } else if (_mod.projectId != 0) {
                    // Otherwise, if a project is specified, make a payment to it.

                    // Get a reference to the Juicebox terminal being used.
                    ITerminal _terminal = terminalDirectory.terminalOf(
                        _mod.projectId
                    );

                    // The project must have a terminal to send funds to.
                    require(
                        _terminal != ITerminal(address(0)),
                        "TerminalV2::_distributeToPayoutMods: BAD_MOD"
                    );

                    // Save gas if this contract is being used as the terminal.
                    if (address(_terminal) == address(dataLayer)) {
                        _pay(
                            _modCut,
                            _mod.projectId,
                            _mod.beneficiary,
                            0,
                            _memo,
                            _mod.preferUnstaked
                        );
                    } else {
                        _terminal.pay{value: _modCut}(
                            _mod.projectId,
                            _mod.beneficiary,
                            _memo,
                            _mod.preferUnstaked
                        );
                    }
                } else {
                    // Otherwise, send the funds directly to the beneficiary.
                    Address.sendValue(_mod.beneficiary, _modCut);
                }

                // Subtract from the amount to be sent to the beneficiary.
                leftoverAmount = leftoverAmount - _modCut;
            }

            emit DistributeToPayoutMod(
                _fundingCycleId,
                _projectId,
                _mod,
                _modCut,
                msg.sender
            );
        }
    }

    /** 
      @notice 
      Takes a fee into the juiceboxDAO's project, which has an id of 1.

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
