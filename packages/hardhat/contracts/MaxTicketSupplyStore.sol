// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./interfaces/IMaxTicketSupplyStore.sol";
import "./abstract/Operatable.sol";
import "./abstract/TerminalUtility.sol";

import "./libraries/Operations.sol";

import "./Tickets.sol";

/** 
  @notice 
  Stores the max supply of tickets that a project wants to have in circulation during a particular funding cycle.
*/
contract MaxTicketSupplyStore is IMaxTicketSupplyStore, TerminalUtility {
    // --- public stored properties --- //

    // Max supply per each funding cycle configuration.
    mapping(uint256 => mapping(uint256 => uint256))
        public
        override maxTicketSupplyOf;

    // --- external transactions --- //

    /** 
      @param _terminalDirectory A directory of a project's current Juicebox terminal to receive payments in.
    */
    constructor(ITerminalDirectory _terminalDirectory)
        TerminalUtility(_terminalDirectory)
    {}

    /** 
      @notice 
      Print new tickets.

      @dev
      Only a project's current terminal can print its tickets.

      @param _projectId The project to set the max ticket supply of.
      @param _configuration The funding cycle configuration during which this max will apply.
      @param _value The value to set the max amount to.
    */
    function set(
        uint256 _projectId,
        uint256 _configuration,
        uint256 _value
    ) external override onlyTerminal(_projectId) {
        // Set the value.
        maxTicketSupplyOf[_projectId][_configuration] = _value;
        emit Set(_projectId, _configuration, _value, msg.sender);
    }
}
