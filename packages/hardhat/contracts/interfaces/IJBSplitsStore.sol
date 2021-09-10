// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IJBOperatorStore.sol";
import "./IJBProjects.sol";
import "./IJBSplitAllocator.sol";

struct Split {
    bool preferUnstaked;
    uint16 percent;
    uint48 lockedUntil;
    address payable beneficiary;
    IJBSplitAllocator allocator;
    uint56 projectId;
}

interface IJBSplitsStore {
    event SetSplit(
        uint256 indexed projectId,
        uint256 indexed configuration,
        uint256 indexed group,
        Split split,
        address caller
    );

    function projects() external view returns (IJBProjects);

    function get(
        uint256 _projectId,
        uint256 _configuration,
        uint256 _group
    ) external view returns (Split[] memory);

    function set(
        uint256 _projectId,
        uint256 _configuration,
        uint256 _group,
        Split[] memory _splits
    ) external;
}
