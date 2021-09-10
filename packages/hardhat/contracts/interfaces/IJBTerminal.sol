// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IJBDirectory.sol";

interface IJBTerminal {
    function directory() external view returns (IJBDirectory);

    function migrationIsAllowed(IJBTerminal _terminal)
        external
        view
        returns (bool);

    function pay(
        uint256 _projectId,
        address _beneficiary,
        uint256 _minReturnedTickets,
        bool _preferUnstakedTickets,
        string calldata _memo,
        bytes calldata _delegateMetadate
    ) external payable returns (uint256 fundingCycleId);

    function prepForMigrationOf(uint256 _projectId) external;

    function addToBalance(uint256 _projectId, string memory _memo)
        external
        payable;

    function dataAuthority() external view returns (address);
}
