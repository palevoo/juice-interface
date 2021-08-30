// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IGovernable {
    event TransferGovernance(address newGovernance);

    function governance() external view returns (address);

    function transferGovernance(address _newGovernance) external;
}
