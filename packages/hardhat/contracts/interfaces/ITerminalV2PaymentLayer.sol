// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./IProjects.sol";
import "./ISplitsStore.sol";
import "./ITerminalDirectory.sol";
import "./ITerminalV2DataLayer.sol";
import "./ITerminalDataLayer.sol";
import "./IFundingCycles.sol";

interface ITerminalV2PaymentLayer {
    event AddToBalance(
        uint256 indexed projectId,
        uint256 value,
        address caller
    );
    event Migrate(
        uint256 indexed projectId,
        ITerminal indexed to,
        uint256 amount,
        address caller
    );
    event DistributePayouts(
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        address projectOwner,
        uint256 amount,
        uint256 tappedAmount,
        uint256 feeAmount,
        uint256 projectOwnerTransferAmount,
        string memo,
        address caller
    );

    event UseAllowance(
        uint256 indexed fundingCycleNumber,
        uint256 indexed configuration,
        uint256 indexed projectId,
        address beneficiary,
        uint256 amount,
        uint256 feeAmount,
        uint256 transferAmount,
        address caller
    );

    event Pay(
        uint256 indexed fundingCycleNumber,
        uint256 indexed projectId,
        address indexed beneficiary,
        FundingCycle fundingCycle,
        uint256 amount,
        uint256 weight,
        uint256 tokenCount,
        string memo,
        address caller
    );
    event Redeem(
        uint256 indexed fundingCycleNumber,
        uint256 indexed projectId,
        address indexed holder,
        FundingCycle fundingCycle,
        address beneficiary,
        uint256 tokenCount,
        uint256 claimedAmount,
        string memo,
        address caller
    );
    event DistributeToPayoutSplit(
        uint256 indexed fundingCycleNumber,
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        Split split,
        uint256 amount,
        address caller
    );

    function projects() external view returns (IProjects);

    function splitsStore() external view returns (ISplitsStore);

    function terminalDirectory() external view returns (ITerminalDirectory);

    function dataLayer() external view returns (ITerminalV2DataLayer);

    function distributePayouts(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei,
        string memory _memo
    ) external returns (uint256);

    function redeemTokens(
        address _holder,
        uint256 _projectId,
        uint256 _count,
        uint256 _minReturnedWei,
        address payable _beneficiary,
        string calldata _memo,
        bytes calldata _delegateMetadata
    ) external returns (uint256 claimedAmount);

    function pay(
        uint256 _projectId,
        address _beneficiary,
        uint256 _minReturnedTickets,
        bool _preferUnstakedTokens,
        string calldata _memo,
        bytes calldata _delegateMetadata
    ) external payable returns (uint256 fundingCycleConfiguration);

    function useAllowance(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei,
        address payable _beneficiary
    ) external returns (uint256 fundingCycleNumber);

    function migrate(uint256 _projectId, ITerminalDataLayer _to) external;

    function addToBalance(uint256 _projectId) external payable;
}
