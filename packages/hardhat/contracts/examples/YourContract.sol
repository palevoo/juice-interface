// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../abstract/PayableJuicebox.sol";

/// @dev This contract is an example of how you can use Juicebox to fund your own project.
contract YourContract is PayableJuicebox {
    constructor(uint256 _projectId, IJBDirectory _jbDirectory)
        PayableJuicebox(_projectId, _jbDirectory)
    {}
}
