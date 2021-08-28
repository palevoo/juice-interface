// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./interfaces/IFundingCycleExtrasStore1.sol";
import "./abstract/TerminalUtility.sol";

/** 
  @notice 
  Stores extra information pertaining to funding cycle configurations.
*/
contract FundingCycleExtrasStore1 is
    IFundingCycleExtrasStore1,
    TerminalUtility
{
    // --- public stored properties --- //

    // The amount of overflow that a project is allowed to tap into itself on-demand.
    mapping(uint256 => mapping(uint256 => uint256))
        public
        override overflowAllowanceOf;

    // The amount of overflow that a project is allowed to tap into itself on-demand.
    mapping(uint256 => mapping(uint256 => IPayGate)) public override payGateOf;

    // --- external transactions --- //

    /** 
      @param _terminalDirectory A directory of a project's current Juicebox terminal to receive payments in.
    */
    constructor(ITerminalDirectory _terminalDirectory)
        TerminalUtility(_terminalDirectory)
    {}

    /** 
      @notice 
      Sets extra properties for a funding cycle configuration.

      @dev
      Only a project's current terminal can set funding cycle extra properties.

      @param _projectId The project to set the extra properties of.
      @param _configuration The funding cycle configuration during which the extra properties will apply.
      @param _extras The extra values to set.
    */
    function set(
        uint256 _projectId,
        uint256 _configuration,
        FundingCycleExtras1 memory _extras
    ) external override onlyTerminal(_projectId) {
        if (
            _extras.overflowAllowance !=
            overflowAllowanceOf[_projectId][_configuration]
        )
            overflowAllowanceOf[_projectId][_configuration] = _extras
                .overflowAllowance;

        if (_extras.payGate != payGateOf[_projectId][_configuration])
            payGateOf[_projectId][_configuration] = _extras.payGate;

        emit Set(_projectId, _configuration, _extras, msg.sender);
    }

    /** 
      @notice 
      Decrements the amount of allowance a funding cycle configuration still has available.

      @dev
      Only a project's current terminal can decrement its allowance.

      @param _projectId The project to decrement allowance from.
      @param _configuration The funding cycle configuration during wich allowance will be decremented.
      @param _amount The amount to decrement.
    */
    function decrementAllowance(
        uint256 _projectId,
        uint256 _configuration,
        uint256 _amount
    ) external override onlyTerminal(_projectId) {
        // There must be sufficient allowance available.
        require(
            _amount <= overflowAllowanceOf[_projectId][_configuration],
            "FundingCycleExtrasStore1::decrementAllowance: NOT_ALLOWED"
        );

        // Store the decremented value.
        overflowAllowanceOf[_projectId][_configuration] =
            overflowAllowanceOf[_projectId][_configuration] -
            _amount;

        emit DecrementAllowance(
            _projectId,
            _configuration,
            _amount,
            msg.sender
        );
    }
}
