// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IFundingCycles.sol";

enum AccessType {
    Disallow,
    Allow,
    AllowWithCallback
}

interface IFundingCycleDelegate {
    function payParams(
        FundingCycle calldata _fundingCycle,
        uint256 _amount,
        address _beneficiary,
        string memory _memo,
        address _caller
    )
        external
        returns (
            uint256 weight,
            string memory memo,
            AccessType accessType
        );

    function redeemParams(
        FundingCycle calldata _fundingCycle,
        uint256 _count,
        address _beneficiary,
        string memory _memo,
        address _caller
    )
        external
        returns (
            uint256 amount,
            string memory memo,
            AccessType accessType
        );

    function payCallback(
        FundingCycle calldata _fundingCycle,
        uint256 _amount,
        uint256 _weight,
        uint256 _count,
        address _beneficiary,
        string memory memo,
        address _caller
    ) external;

    function redeemCallback(
        FundingCycle calldata _fundingCycle,
        uint256 _count,
        uint256 _amount,
        address _beneficiary,
        string memory memo,
        address _caller
    ) external;
}
