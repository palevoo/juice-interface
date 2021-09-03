// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IFundingCycles.sol";

import "./IPayDelegate.sol";
import "./IRedemptionDelegate.sol";

interface IFundingCycleDataSource {
    function payData(
        address _payer,
        uint256 _amount,
        uint256 _baseWeight,
        uint256 _reservedRate,
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
        address _holder,
        uint256 _count,
        uint256 _redemptionRate,
        uint256 _ballotRedemptionRate,
        address _beneficiary,
        string calldata _memo
    )
        external
        returns (
            uint256 amount,
            string calldata memo,
            IRedemptionDelegate delegate
        );
}
