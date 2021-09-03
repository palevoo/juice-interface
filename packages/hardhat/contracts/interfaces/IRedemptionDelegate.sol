// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IFundingCycles.sol";

interface IRedemptionDelegate {
    function didRedeem(
        FundingCycle calldata _fundingCycle,
        address _holder,
        uint256 _count,
        uint256 _amount,
        address _beneficiary,
        string calldata memo
    ) external;
}
