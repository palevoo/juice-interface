// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./TerminalV1.sol";

import "./interfaces/ITerminalV1Point1.sol";
import "./libraries/Operations2.sol";

/** 
  Includes burn.
*/
contract TerminalV1Point1 is TerminalV1, ITerminalV1Point1 {
    /** 
      @param _projects A Projects contract which mints ERC-721's that represent project ownership and transfers.
      @param _fundingCycles A funding cycle configuration store.
      @param _ticketBooth A contract that manages Ticket printing and redeeming.
      @param _modStore A storage for a project's mods.
      @param _prices A price feed contract to use.
      @param _terminalDirectory A directory of a project's current Juicebox terminal to receive payments in.
    */
    constructor(
        IProjects _projects,
        IFundingCycles _fundingCycles,
        ITicketBooth _ticketBooth,
        IOperatorStore _operatorStore,
        IModStore _modStore,
        IPrices _prices,
        ITerminalDirectory _terminalDirectory,
        address payable _governance
    )
        TerminalV1(
            _projects,
            _fundingCycles,
            _ticketBooth,
            _operatorStore,
            _modStore,
            _prices,
            _terminalDirectory,
            _governance
        )
    {}

    function burn(
        address _account,
        uint256 _projectId,
        uint256 _count,
        bool _preferUnstaked
    )
        external
        override
        nonReentrant
        requirePermissionAllowingWildcardDomain(
            _account,
            _projectId,
            Operations2.Burn
        )
    {
        // Redeem the tickets, which burns them.
        ticketBooth.redeem(_account, _projectId, _count, _preferUnstaked);

        emit Burn(_account, _projectId, _count, _preferUnstaked, msg.sender);
    }

    /** 
      @notice 
      Receives and allocates funds belonging to the specified project.

      @param _projectId The ID of the project to which the funds received belong.
    */
    function addToBalanceWithMemo(uint256 _projectId, string calldata _memo)
        external
        payable
        override
    {
        // The amount must be positive.
        require(msg.value > 0, "TerminalV1Point1::addToBalance: BAD_AMOUNT");
        balanceOf[_projectId] = balanceOf[_projectId] + msg.value;
        emit AddToBalanceWithMemo(_projectId, msg.value, _memo, msg.sender);
    }
}
