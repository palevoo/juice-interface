// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./TerminalUtility.sol";
import "./../interfaces/IBootloadableTerminalUtility.sol";

abstract contract BootloadableTerminalUtility is
    TerminalUtility,
    IBootloadableTerminalUtility
{
    modifier onlyTerminalOrBootloader(uint256 _projectId) {
        require(
            msg.sender == address(terminalDirectory.terminalOf(_projectId)) ||
                msg.sender == bootloader,
            "TerminalUtility: UNAUTHORIZED"
        );
        _;
    }

    /// @notice The direct deposit terminals.
    address public immutable override bootloader;

    /** 
      @param _terminalDirectory A directory of a project's current Juicebox terminal to receive payments in.
    */
    constructor(ITerminalDirectory _terminalDirectory, address _bootloader)
        TerminalUtility(_terminalDirectory)
    {
        bootloader = _bootloader;
    }
}
