// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IFundingCycles.sol";

import "./IPayDelegate.sol";
import "./IRedeemDelegate.sol";

interface IFundingCycleDataSource {
    function payData(
        FundingCycle calldata _fundingCycle,
        address _payer,
        uint256 _amount,
        address _beneficiary,
        string calldata _memo
    )
        external
        returns (
            uint256 weight,
            string calldata memo,
            IPayDelegate delegate
        );

    function redeemData(
        FundingCycle calldata _fundingCycle,
        address _holder,
        uint256 _count,
        address _beneficiary,
        string calldata _memo
    )
        external
        returns (
            uint256 amount,
            string calldata memo,
            IRedeemDelegate delegate
        );
}
