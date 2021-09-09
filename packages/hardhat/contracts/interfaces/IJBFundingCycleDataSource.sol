// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IJBFundingCycleStore.sol";

import "./IPayDelegate.sol";
import "./IRedemptionDelegate.sol";

struct PayDataParam {
    address payer;
    uint256 amount;
    uint256 weight;
    uint256 reservedRate;
    address beneficiary;
    string memo;
    bytes _delegateMetadata;
}

struct RedeemDataParam {
    address holder;
    uint256 count;
    uint256 redemptionRate;
    uint256 ballotRedemptionRate;
    address beneficiary;
    string memo;
    bytes delegateMetadata;
}

interface IJBFundingCycleDataSource {
    function payData(PayDataParam calldata _param)
        external
        returns (
            uint256 weight,
            string memory memo,
            IPayDelegate delegate,
            bytes memory delegateMetadata
        );

    function redeemData(RedeemDataParam calldata _param)
        external
        returns (
            uint256 amount,
            string memory memo,
            IRedemptionDelegate delegate,
            bytes memory delegateMetadata
        );
}
