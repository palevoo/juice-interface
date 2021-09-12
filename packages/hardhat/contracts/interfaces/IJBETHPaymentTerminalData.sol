// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./IJBTokenStore.sol";
import "./IJBFundingCycleStore.sol";
import "./IJBProjects.sol";
import "./IJBSplitsStore.sol";
import "./IJBTerminal.sol";
import "./IOperatorStore.sol";
import "./IJBFundingCycleDataSource.sol";
import "./IJBPrices.sol";
import "./IJBController.sol";

interface IJBETHPaymentTerminalData {
    event SetOverflowAllowance(
        uint256 indexed projectId,
        uint256 indexed configuration,
        uint256 amount,
        address caller
    );

    event SetPaymentTerminal(IJBTerminal terminal, address caller);

    event DelegateDidPay(IJBPayDelegate indexed delegate, DidPayParam param);

    event DelegateDidRedeem(
        IJBRedemptionDelegate indexed delegate,
        DidRedeemParam param
    );

    function fundingCycleStore() external view returns (IJBFundingCycleStore);

    function tokenStore() external view returns (IJBTokenStore);

    function prices() external view returns (IJBPrices);

    function directory() external view returns (IJBDirectory);

    function jb() external view returns (IJBController);

    function paymentTerminal() external view returns (IJBTerminal);

    function balanceOf(uint256 _projectId) external view returns (uint256);

    function usedOverflowAllowanceOf(uint256 _projectId, uint256 _configuration)
        external
        view
        returns (uint256);

    function currentOverflowOf(uint256 _projectId)
        external
        view
        returns (uint256);

    function claimableOverflowOf(uint256 _projectId, uint256 _tokenCount)
        external
        view
        returns (uint256);

    function recordPaymentFrom(
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

    function recordWithdrawalFor(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei
    )
        external
        returns (FundingCycle memory fundingCycle, uint256 withdrawnAmount);

    function recordUsedAllowanceOf(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei
    )
        external
        returns (FundingCycle memory fundingCycle, uint256 withdrawnAmount);

    function recordRedemptionFor(
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

    function recordBalanceTransferFor(uint256 _projectId, IJBTerminal _terminal)
        external
        returns (uint256 balance);

    function recordAddedBalanceFor(uint256 _projectId, uint256 _amount)
        external;

    function setPaymentTerminalOf(IJBTerminal _paymentTerminal) external;
}
