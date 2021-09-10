// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./interfaces/IJBTerminal.sol";
import "./interfaces/IJBDirectory.sol";
import "./interfaces/IProjects.sol";

import "./abstract/JBOperatable.sol";

import "./libraries/Operations.sol";

import "./DirectPaymentAddress.sol";

/**
  @notice
  Allows project owners to deploy proxy contracts that can pay them when receiving funds directly.
*/
contract JBDirectory is IJBDirectory, JBOperatable {
    // --- public immutable stored properties --- //

    /// @notice The Projects contract which mints ERC-721's that represent project ownership and transfers.
    IJBProjects public immutable override projects;

    // --- public stored properties --- //

    /// @notice For each project ID, the juicebox terminal that the direct payment addresses are proxies for.
    mapping(uint256 => IJBTerminal) public override terminalOf;

    // --- external transactions --- //

    /** 
      @param _projects A Projects contract which mints ERC-721's that represent project ownership and transfers.
      @param _operatorStore A contract storing operator assignments.
    */
    constructor(IJBProjects _projects, IJBOperatorStore _operatorStore)
        JBOperatable(_operatorStore)
    {
        projects = _projects;
    }

    /** 
      @notice 
      Update the juicebox terminal that payments to direct payment addresses will be forwarded for the specified project ID.

      @param _projectId The ID of the project to set a new terminal for.
      @param _terminal The new terminal to set.
    */
    function setTerminal(uint256 _projectId, IJBTerminal _terminal)
        external
        override
    {
        // Get a reference to the current terminal being used.
        IJBTerminal _currentTerminal = terminalOf[_projectId];

        address _projectOwner = projects.ownerOf(_projectId);

        // Either:
        // - case 1: the current terminal hasn't been set yet and the msg sender is either the projects contract or the terminal being set.
        // - case 2: the current terminal must not yet be set, or the current terminal is setting a new terminal.
        // - case 3: the msg sender is the owner or operator and either the current terminal hasn't been set, or the current terminal allows migration to the terminal being set.
        require(
            // case 1.
            (_currentTerminal == IJBTerminal(address(0)) &&
                (msg.sender == address(projects) ||
                    msg.sender == address(_terminal))) ||
                // case 2.
                msg.sender == address(_currentTerminal) ||
                // case 3.
                ((msg.sender == _projectOwner ||
                    operatorStore.hasPermission(
                        msg.sender,
                        _projectOwner,
                        _projectId,
                        Operations.SetTerminal
                    )) &&
                    (_currentTerminal == IJBTerminal(address(0)) ||
                        _currentTerminal.migrationIsAllowed(_terminal))),
            "JBDirectory::setTerminal: UNAUTHORIZED"
        );

        // The project must exist.
        require(
            projects.exists(_projectId),
            "JBDirectory::setTerminal: NOT_FOUND"
        );

        // Can't set the zero address.
        require(
            _terminal != IJBTerminal(address(0)),
            "JBDirectory::setTerminal: ZERO_ADDRESS"
        );

        // If the terminal is already set, nothing to do.
        if (_currentTerminal == _terminal) return;

        // Set the new terminal.
        terminalOf[_projectId] = _terminal;

        emit SetTerminal(_projectId, _terminal, msg.sender);
    }
}
