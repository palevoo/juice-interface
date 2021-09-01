// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./IOperatorStore.sol";
import "./IProjects.sol";
import "./ISplitAllocator.sol";

struct Split {
    bool preferUnstaked;
    uint16 percent;
    uint48 lockedUntil;
    address payable beneficiary;
    ISplitAllocator allocator;
    uint56 projectId;
}

interface ISplitsStore {
    event SetSplit(
        uint256 indexed projectId,
        uint256 indexed configuration,
        uint256 indexed group,
        Split split,
        address caller
    );

    function projects() external view returns (IProjects);

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
