// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./ITicketBooth.sol";
import "./IFundingCycles.sol";
import "./ITerminalDataSource.sol";
import "./IYielder.sol";
import "./IProjects.sol";
import "./IModStore.sol";
import "./ITerminal.sol";
import "./IOperatorStore.sol";

struct FundingCycleMetadataV2 {
    uint256 reservedRate;
    uint256 bondingCurveRate;
    uint256 reconfigurationBondingCurveRate;
    bool pausePay;
    bool pauseTap;
    bool pauseRedeem;
    bool pausePrintReserves;
    bool useDataSourceForPay;
    bool useDataSourceForRedeem;
    ITerminalDataSource dataSource;
}

interface ITerminalV2Store {
    event PrintReserveTokens(
        uint256 indexed fundingCycleNumber,
        uint256 indexed projectId,
        address indexed beneficiary,
        uint256 count,
        uint256 beneficiaryTokenAmount,
        string memo,
        address caller
    );

    event DistributeToTicketMod(
        uint256 indexed fundingCycleNumber,
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        TicketMod mod,
        uint256 modCut,
        address caller
    );

    event PrintPreminedTokens(
        uint256 indexed projectId,
        address indexed beneficiary,
        uint256 amount,
        uint256 weight,
        uint256 weightedAmount,
        uint256 currency,
        string memo,
        address caller
    );

    event AllowMigration(ITerminal terminal);

    function fundingCycles() external view returns (IFundingCycles);

    function ticketBooth() external view returns (ITicketBooth);

    function prices() external view returns (IPrices);

    function modStore() external view returns (IModStore);

    function projects() external view returns (IProjects);

    function balanceOf(uint256 _projectId) external view returns (uint256);

    function fee() external view returns (uint256);

    function canPrintPreminedTokens(uint256 _projectId)
        external
        view
        returns (bool);

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

    function mintPreminedTokens(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _weight,
        address _beneficiary,
        string memory _memo,
        bool _preferUnstakedTokens
    ) external;

    function deploy(
        address _owner,
        bytes32 _handle,
        string calldata _uri,
        FundingCycleProperties calldata _properties,
        FundingCycleMetadataV2 calldata _metadata,
        PayoutMod[] memory _payoutMods,
        TicketMod[] memory _ticketMods
    ) external;

    function configure(
        uint256 _projectId,
        FundingCycleProperties calldata _properties,
        FundingCycleMetadataV2 calldata _metadata,
        PayoutMod[] memory _payoutMods,
        TicketMod[] memory _ticketMods
    ) external returns (uint256);

    function addToBalance(uint256 _amount, uint256 _projectId) external payable;

    function tap(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei
    )
        external
        returns (FundingCycle memory fundingCycle, uint256 tappedWeiAmount);

    function redeem(
        address _account,
        uint256 _projectId,
        uint256 _amount,
        uint256 _minReturnedWei,
        address payable _beneficiary,
        string calldata _memo,
        bool _preferUnstaked
    )
        external
        returns (
            FundingCycle memory fundingCycle,
            uint256 claimAmount,
            string memory _delegatedMemo
        );

    function pay(
        uint256 _amount,
        uint256 _projectId,
        address _beneficiary,
        uint256 _minReturnedTokens,
        string memory _memo,
        bool _preferUnstakedTokens
    )
        external
        returns (
            FundingCycle memory fundingCycle,
            uint256 weight,
            uint256 ticketCount,
            string memory delegatedMemo
        );

    function mintReservedTokens(uint256 _projectId, string memory _memo)
        external
        returns (uint256 amount);

    function migrate(uint256 _projectId, ITerminal _to) external payable;
}
