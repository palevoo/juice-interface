// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./ITicketBooth.sol";

struct FundingCycleExtras1 {
    uint256 maxTicketSupply;
    uint256 overflowAllowance;
}

interface IFundingCycleExtrasStore1 {
    event Set(
        uint256 indexed projectId,
        uint256 indexed configuration,
        FundingCycleExtras1 extras,
        address caller
    );

    event DecrementAllowance(
        uint256 indexed projectId,
        uint256 indexed configuration,
        uint256 amount,
        address caller
    );

    function maxTicketSupplyOf(uint256 _projectId, uint256 _configuration)
        external
        view
        returns (uint256);

    function overflowAllowanceOf(uint256 _projectId, uint256 _configuration)
        external
        view
        returns (uint256);

    function set(
        uint256 _projectId,
        uint256 _configuration,
        FundingCycleExtras1 memory _extras
    ) external;

    function decrementAllowance(
        uint256 _projectId,
        uint256 _configuration,
        uint256 _amount
    ) external;
}
