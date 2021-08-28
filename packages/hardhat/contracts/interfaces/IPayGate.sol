// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IFundingCycles.sol";

interface IPayGate {
    function check(
        uint256 _projectId,
        uint256 _amount,
        address _beneficiary,
        FundingCycle calldata _fundingCycle
    )
        external
        returns (
            uint256 _payWeight,
            uint256 _payReservedRate,
            bool disallowed
        );
}
