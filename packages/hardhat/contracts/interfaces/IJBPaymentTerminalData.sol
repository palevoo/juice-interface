// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./IJBTokenStore.sol";
import "./IJBFundingCycleStore.sol";
import "./IJBProjects.sol";
import "./IJBSplitsStore.sol";
import "./IJBTerminal.sol";
import "./IOperatorStore.sol";
import "./IJBPaymentTerminal.sol";
import "./IJBFundingCycleDataSource.sol";
import "./IJBPrices.sol";

struct FundingCycleMetadataV2 {
    uint256 reservedRate;
    uint256 redemptionRate;
    uint256 ballotRedemptionRate;
    bool pausePay;
    bool pauseWithdraw;
    bool pauseRedeem;
    bool pauseMint;
    bool pauseBurn;
    bool useDataSourceForPay;
    bool useDataSourceForRedeem;
    IJBFundingCycleDataSource dataSource;
}

interface IJBPaymentTerminalData {
    event SetOverflowAllowance(
        uint256 indexed projectId,
        uint256 indexed configuration,
        uint256 amount,
        address caller
    );
    event DistributeReservedTokens(
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        address indexed beneficiary,
        uint256 count,
        uint256 projectOwnerTokenCount,
        string memo,
        address caller
    );

    event DistributeToReservedTokenSplit(
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        Split split,
        uint256 tokenCount,
        address caller
    );

    event MintTokens(
        address indexed beneficiary,
        uint256 indexed projectId,
        uint256 amount,
        uint256 currency,
        uint256 weight,
        uint256 count,
        string memo,
        address caller
    );

    event BurnTokens(
        address indexed holder,
        uint256 indexed projectId,
        uint256 count,
        string memo,
        address caller
    );

    event SetPaymentTerminal(IJBTerminal terminal, address caller);

    event DelegateDidPay(IJBPayDelegate indexed delegate, DidPayParam param);

    event DelegateDidRedeem(
        IJBRedemptionDelegate indexed delegate,
        DidRedeemParam param
    );

    function directory() external view returns (IJBDirectory);

    function fundingCycleStore() external view returns (IJBFundingCycleStore);

    function tokenStore() external view returns (IJBTokenStore);

    function prices() external view returns (IJBPrices);

    function splitsStore() external view returns (IJBSplitsStore);

    function projects() external view returns (IJBProjects);

    function paymentTerminal() external view returns (IJBTerminal);

    function fee() external view returns (uint256);

    function balanceOf(uint256 _projectId) external view returns (uint256);

    function remainingOverflowAllowanceOf(
        uint256 _projectId,
        uint256 _configuration
    ) external view returns (uint256);

    function currentOverflowOf(uint256 _projectId)
        external
        view
        returns (uint256);

    function claimableOverflowOf(uint256 _projectId, uint256 _tokenCount)
        external
        view
        returns (uint256);

    function reservedTokenBalanceOf(uint256 _projectId, uint256 _reservedRate)
        external
        view
        returns (uint256);

    function launchProject(
        address _owner,
        bytes32 _handle,
        string calldata _uri,
        FundingCycleProperties calldata _properties,
        FundingCycleMetadataV2 calldata _metadata,
        uint256 _overflowAllowance,
        Split[] memory _payoutSplits,
        Split[] memory _reservedTokenSplits
    ) external;

    function reconfigureFundingCycles(
        uint256 _projectId,
        FundingCycleProperties calldata _properties,
        FundingCycleMetadataV2 calldata _metadata,
        uint256 _overflowAllowance,
        Split[] memory _payoutSplits,
        Split[] memory _reservedTokenSplits
    ) external returns (uint256);

    function recordAddedBalance(uint256 _amount, uint256 _projectId) external;

    function recordWithdrawal(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei
    )
        external
        returns (FundingCycle memory fundingCycle, uint256 withdrawnAmount);

    function recordUsedAllowance(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei
    )
        external
        returns (FundingCycle memory fundingCycle, uint256 withdrawnAmount);

    function recordRedemption(
        address _holder,
        uint256 _projectId,
        uint256 _tokenCount,
        uint256 _minReturnedWei,
        address payable _beneficiary,
        string memory _memo,
        bytes memory _delegateMetadata
    )
        external
        returns (
            FundingCycle memory fundingCycle,
            uint256 claimAmount,
            string memory _delegatedMemo
        );

    function burnTokens(
        address _holder,
        uint256 _projectId,
        uint256 _tokenCount,
        string calldata _memo,
        bool _preferUnstakedTokens
    ) external;

    function mintTokens(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _weight,
        address _beneficiary,
        string calldata _memo,
        bool _preferUnstakedTokens
    ) external returns (uint256 tokenCount);

    function recordPayment(
        address _payer,
        uint256 _amount,
        uint256 _projectId,
        uint256 _preferUnstakedTokensAndBeneficiary,
        uint256 _minReturnedTokens,
        string memory _memo,
        bytes memory _delegateMetadata
    )
        external
        returns (
            FundingCycle memory fundingCycle,
            uint256 weight,
            uint256 ticketCount,
            string memory delegatedMemo
        );

    function distributeReservedTokens(uint256 _projectId, string memory _memo)
        external
        returns (uint256 amount);

    function recordMigration(uint256 _projectId)
        external
        returns (uint256 balance);

    function recordPrepForMigrationOf(uint256 _projectId) external;

    function setPaymentTerminal(IJBTerminal _paymentTerminal) external;
}
