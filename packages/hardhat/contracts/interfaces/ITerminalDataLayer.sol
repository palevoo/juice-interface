// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./ITerminal.sol";

interface ITerminalDataLayer is ITerminal {
    function prepToReceiveBalanceFor(uint256 _projectId) external;
}
