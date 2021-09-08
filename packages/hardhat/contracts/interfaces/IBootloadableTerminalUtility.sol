// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./ITerminalUtility.sol";

interface IBootloadableTerminalUtility is ITerminalUtility {
    function bootloader() external view returns (address);
}
