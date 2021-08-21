// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./ITicketBooth.sol";

interface IMaxTicketSupplyStore {
    event Set(
        uint256 indexed projectId,
        uint256 indexed configuration,
        uint256 indexed value,
        address caller
    );

    function maxTicketSupplyOf(uint256 _projectId, uint256 _configuration)
        external
        view
        returns (uint256);

    function set(
        uint256 _projectId,
        uint256 _configuration,
        uint256 _value
    ) external;
}
