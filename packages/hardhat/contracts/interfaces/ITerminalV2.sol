// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./ITicketBooth.sol";
import "./IFundingCycles.sol";
import "./IFundingCycleDelegate.sol";
import "./IYielder.sol";
import "./IProjects.sol";
import "./IModStore.sol";
import "./ITerminal.sol";
import "./IOperatorStore.sol";

struct FundingCycleMetadataV2 {
    uint256 reservedRate;
    uint256 bondingCurveRate;
    uint256 reconfigurationBondingCurveRate;
    bool usePayDelegate;
    bool useRedeemDelegate;
    IFundingCycleDelegate delegate;
}

interface ITerminalV2 {
    event Tap(
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        address indexed beneficiary,
        uint256 amount,
        uint256 netTransferAmount,
        uint256 beneficiaryTransferAmount,
        uint256 govFeeAmount,
        string memo,
        address caller
    );
    event Redeem(
        address indexed holder,
        address indexed beneficiary,
        uint256 indexed _projectId,
        uint256 amount,
        uint256 returnAmount,
        string memo,
        address caller
    );

    event PrintReserveTickets(
        uint256 indexed fundingCycleNumber,
        uint256 indexed projectId,
        address indexed beneficiary,
        uint256 count,
        uint256 beneficiaryTicketAmount,
        string memo,
        address caller
    );

    event DistributeToPayoutMod(
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        PayoutMod mod,
        uint256 modCut,
        address caller
    );
    event DistributeToTicketMod(
        uint256 indexed fundingCycleId,
        uint256 indexed projectId,
        TicketMod mod,
        uint256 modCut,
        address caller
    );
    event AppointGovernance(address governance);

    event AcceptGovernance(address governance);

    event PrintPreminedTickets(
        uint256 indexed projectId,
        address indexed beneficiary,
        uint256 amount,
        uint256 weight,
        uint256 weightedAmount,
        uint256 currency,
        string memo,
        address caller
    );

    event Deposit(uint256 amount);

    event TransferGovernance(address governance);

    function governance() external view returns (address);

    function projects() external view returns (IProjects);

    function fundingCycles() external view returns (IFundingCycles);

    function ticketBooth() external view returns (ITicketBooth);

    function prices() external view returns (IPrices);

    function modStore() external view returns (IModStore);

    function reservedTicketBalanceOf(uint256 _projectId, uint256 _reservedRate)
        external
        view
        returns (uint256);

    function canPrintPreminedTickets(uint256 _projectId)
        external
        view
        returns (bool);

    function balanceOf(uint256 _projectId) external view returns (uint256);

    function currentOverflowOf(uint256 _projectId)
        external
        view
        returns (uint256);

    function claimableOverflowOf(uint256 _amount, uint256 _projectId)
        external
        view
        returns (uint256);

    function fee() external view returns (uint256);

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

    function printPreminedTickets(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _weight,
        address _beneficiary,
        string memory _memo,
        bool _preferUnstakedTickets
    ) external;

    function tap(
        uint256 _projectId,
        uint256 _amount,
        uint256 _currency,
        uint256 _minReturnedWei,
        string memory _memo
    ) external returns (uint256);

    function redeem(
        address _account,
        uint256 _projectId,
        uint256 _amount,
        uint256 _minReturnedWei,
        address payable _beneficiary,
        string memory _memo,
        bool _preferUnstaked
    ) external returns (uint256 returnAmount);

    function printReservedTickets(uint256 _projectId, string memory _memo)
        external
        returns (uint256 reservedTicketsToPrint);

    function transferGovernance(address _newGovernance) external;

    function pay(
        uint256 _projectId,
        address _beneficiary,
        uint256 _minReturnedTickets,
        string calldata _memo,
        bool _preferUnstakedTickets
    ) external payable returns (uint256 fundingCycleId);
}
