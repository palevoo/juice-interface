// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IPayGate {
    function isAllowed(
        uint256 _amount,
        address _beneficiary,
        uint256 _weightedAmount,
        uint256 _reservedRate
    ) external returns (bool);
}
