// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface ITerminalV1Point1 {
    event Burn(
        address indexed holder,
        uint256 indexed projectId,
        uint256 amount,
        bool preferUnstaked,
        address caller
    );

    event AddToBalanceWithMemo(
        uint256 indexed projectId,
        uint256 value,
        string memo,
        address caller
    );

    function burn(
        address _account,
        uint256 _projectId,
        uint256 _count,
        bool _preferUnstaked
    ) external;

    function addToBalanceWithMemo(uint256 _projectId, string calldata _memo)
        external
        payable;
}
