// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IGovernable.sol";

interface IGovernance {
    function transferGovernance(IGovernable _governable, address _newGovernance)
        external;
}
