## `TerminalV1`

/**
  ─────────────────────────────────────────────────────────────────────────────────────────────────
  ─────────██████──███████──██████──██████████──██████████████──██████████████──████████████████───
  ─────────██░░██──███░░██──██░░██──██░░░░░░██──██░░░░░░░░░░██──██░░░░░░░░░░██──██░░░░░░░░░░░░██───
  ─────────██░░██──███░░██──██░░██──████░░████──██░░██████████──██░░██████████──██░░████████░░██───
  ─────────██░░██──███░░██──██░░██────██░░██────██░░██──────────██░░██──────────██░░██────██░░██───
  ─────────██░░██──███░░██──██░░██────██░░██────██░░██──────────██░░██████████──██░░████████░░██───
  ─────────██░░██──███░░██──██░░██────██░░██────██░░██──────────██░░░░░░░░░░██──██░░░░░░░░░░░░██───
  ─██████──██░░██──███░░██──██░░██────██░░██────██░░██──────────██░░██████████──██░░██████░░████───
  ─██░░██──██░░██──███░░██──██░░██────██░░██────██░░██──────────██░░██──────────██░░██──██░░██─────
  ─██░░██████░░██──███░░██████░░██──████░░████──██░░██████████──██░░██████████──██░░██──██░░██████─
  ─██░░░░░░░░░░██──███░░░░░░░░░░██──██░░░░░░██──██░░░░░░░░░░██──██░░░░░░░░░░██──██░░██──██░░░░░░██─
  ─██████████████──███████████████──██████████──██████████████──██████████████──██████──██████████─
  ───────────────────────────────────────────────────────────────────────────────────────────

  @notice 
  This contract manages the Juicebox ecosystem, serves as a payment terminal, and custodies all funds.

  @dev 
  A project can transfer its funds, along with the power to reconfigure and mint/burn their Tickets, from this contract to another allowed terminal contract at any time.
/
contract TerminalV1 is Operatable, ITerminalV1, ITerminal, ReentrancyGuard {
    // Modifier to only allow governance to call the function.
    modifier onlyGov() {
        require(msg.sender == governance, "TerminalV1: UNAUTHORIZED");
        _;
    }

    // --- private stored properties --- //

    // The difference between the processed ticket tracker of a project and the project's ticket's total supply is the amount of tickets that
    // still need to have reserves printed against them.
    mapping(uint256 => int256) private _processedTicketTrackerOf;

    // The amount of ticket printed prior to a project configuring their first funding cycle.
    mapping(uint256 => uint256) private _preconfigureTicketCountOf;

    // --- public immutable stored properties --- //

The Projects contract which mints ERC-721's that represent project ownership and transfers.
    IProjects public immutable override projects;

The contract storing all funding cycle configurations.
    IFundingCycles public immutable override fundingCycles;

The contract that manages Ticket printing and redeeming.
    ITicketBooth public immutable override ticketBooth;

The contract that stores mods for each project.
    IModStore public immutable override modStore;

The prices feeds.
    IPrices public immutable override prices;

The directory of terminals.
    ITerminalDirectory public immutable override terminalDirectory;

    // --- public stored properties --- //

The amount of ETH that each project is responsible for.
    mapping(uint256 => uint256) public override balanceOf;

The percent fee the Juicebox project takes from tapped amounts. Out of 200.
    uint256 public override fee = 10;

The governance of the contract who makes fees and can allow new TerminalV1 contracts to be migrated to by project owners.
    address payable public override governance;

The governance of the contract who makes fees and can allow new TerminalV1 contracts to be migrated to by project owners.
    address payable public override pendingGovernance;

    // Whether or not a particular contract is available for projects to migrate their funds and Tickets to.
    mapping(ITerminal => bool) public override migrationIsAllowed;

    // --- external views --- //

    /** 
      @notice 
      Gets the current overflowed amount for a specified project.

      @



### `onlyGov()`






### `currentOverflowOf(uint256 _projectId) → uint256 overflow` (external)

_fundingCycle = fundingCycles.currentOf(_projectId);

        // There's no overflow if there's no funding cycle.
        if (_fundingCycle.id == 0) return 0;

        // Get the amount of current overflow.
        uint256 _curren



### `reservedTicketBalanceOf(uint256 _projectId, uint256 _reservedRate) → uint256` (external)

TicketAmountFrom(
            _processedTicketTrackerOf[_projectId],
            uint256(uint8(_fundingCycle.metadata >> 8)),
            _totalSupply
        );

        // If there are reserved tickets, add them to the total supply.
        if (_reservedTicketAmount > 0)
            _totalSupply = _totalSupp



### `claimableOverflowOf(address _account, uint256 _projectId, uint256 _count) → uint256` (public)

according to the previous funding cycle's ballot.
        uint256 _bondingCurveRate = fundingCycles.currentBallotStateOf(
            _projectId
        ) == BallotState.Active // The reconfiguration bonding curve rate is stored in bytes 24-31 of the metadata property.
            ? uint256(uint8(_fundingCycle.metadata >> 24)) // The bonding curve rate is stored in bytes 16-23 of the data property after.
            : uint256(uint8(_fundingCycle.metadata >> 16));

        // The bonding curve formula.
        // https://www.desmos.com/calculator/sp9ru6zbpk
        // where x is _count, o is _curren



### `canPrintPreminedTickets(uint256 _projectId) → bool` (public)

vernance;
    }

    /**
      @notice 
      Deploys a project. This will mint an ERC-721 into the `_owner`'s account, configure a first funding cycle, and set up any mods.

      @dev



### `constructor(contract IProjects _projects, contract IFundingCycles _fundingCycles, contract ITicketBooth _ticketBooth, contract IOperatorStore _operatorStore, contract IModStore _modStore, contract IPrices _prices, contract ITerminalDirectory _terminalDirectory, address payable _governance)` (public)

_properties.cycleLimit The number of cycles that this configuration should last for before going back to the last permanent. This has no effect for a project's first funding cycle.
        @dev _properties.discountRate A number from 0-200 indicating how valuable a contribution to this funding stage is compared to the project's previous funding stage.
          If it's 200, each funding stage will have equal weight.
          If the number is 180, a contribution to the next fundin



### `deploy(address _owner, bytes32 _handle, string _uri, struct FundingCycleProperties _properties, struct FundingCycleMetadata _metadata, struct PayoutMod[] _payoutMods, struct TicketMod[] _ticketMods)` (external)

to set.
/
    function deploy(
        address _owner,
        bytes32 _handle,
        string calldata _uri,
        FundingCycleProperties calldata _properties,
        FundingCycleMetadata calldata _metadata,
        PayoutMod[] memory _payoutMods,
        TicketMod[] memory _ticketMods
    ) external override {
        // Make sure the metadata checks out. If it does, return a packed version of it.
        uint256 _packedMetadata = _validateAndPackFundingCycleMetadata(
            _metadata
        );

        // Create the project for the owner.
        uint256 _projectId = projects.create(_owner, _handle, _uri, this);

        // Configure the funding stage's state.
        FundingCycle memory _fundingCycle = fundingCycles.configure(
            _projectId,
            _properties,
            _packedMetadata,
            fee,
            true
        );

        // Set payout mods if there are any.
        if (_payoutMods.length > 0)
            modStore.setPayoutMods(
                _projectId,
                _fundingCycle.configured,
                _payoutMods
            );

        // Set ticket mods if there are any.
        if (_ticketMods.length > 0)
            modStore.setTicketMods(
                _projectId,
                _fundingCycle.configured,
                _ticketMods
            );
    }

    /**
      @notice 
      Configures the properties of the current funding cycle if the project hasn't distributed tickets yet, or
      sets the properties of the proposed funding cycle that will take effect once the current one expires
      if it is approved by the current funding cycle's ballot.

      @dev
      Only a project's owner or a designated operator can configure its funding cycles.

      @param _projectId The ID of the project being reconfigured. 
      @param _properties The funding cycle configuration.
        @dev _properties.target The amount that the project wants to receive in this funding stage. Sent as a wad.
        @dev _properties.currency The currency of the `target`. Send 0 for ETH or 1 for USD.
        @dev _properties.duration The duration of the funding stage for which the `target` amount is needed. Measured in days. Send 0 for a boundless cycle reconfigurable at any time.
        @dev _properties.cycleLimit The number of cycles that this configuration should last for before going back to the last permanent. This has no effect for a project's first funding cycle.
        @dev _properties.discountRate A number from 0-200 ind



### `configure(uint256 _projectId, struct FundingCycleProperties _properties, struct FundingCycleMetadata _metadata, struct PayoutMod[] _payoutMods, struct TicketMod[] _ticketMods) → uint256` (external)

e(
        uint256 _projectId,
        FundingCycleProperties calldata _properties,
        FundingCycleMetadata calldata _metadata,
        PayoutMod[] memory _payoutMods,
        TicketMod[] memory _ticketMods
    )
        external
        override
        requirePermission(
            projects.ownerOf(_projectId),
            _projectId,
            Operations.Configure
        )
        returns (uint256)
    {
        // Make sure the metadata is validated, and pack it into a uint256.
        uint256 _packedMetadata = _validateAndPackFundingCycleMetadata(
            _metadata
        );

        // If the project can still print premined tickets configure the active funding cycle instead of creating a standby one.
        bool _shouldConfigureActive = canPrintPreminedTickets(_projectId);

        // Configure the funding stage's state.
        FundingCycle memory _fundingCycle = fundingCycles.configure(
            _projectId,
            _properties,
            _packedMetadata,
            fee,
            _shouldConfigureActive
        );

        // Set payout mods for the new configuration if there are any.
        if (_payoutMods.length > 0)
            modStore.setPayoutMods(
                _projectId,
                _fundingCycle.configured,
                _payoutMods
            );

        // Set payout mods for the new configuration if there are any.
        if (_ticketMods.length > 0)
            modStore.setTicketMods(
                _projectId,
                _fundingCycle.configured,
                _ticketMods
            );

        return _fundingCycle.id;
    }

    /** 
      @notice 
      Allows a project to print tickets for a specified beneficiary before payments have been received.

      @dev 
      This can only be done if the project hasn't yet received a payment after configuring a funding cycle.

      @dev
      Only a project's owner or a designated operator can print premined tickets.

      @param _projectId The ID of the project to premine tickets for.
      @param _amount The amount to base the ticket premine off of.
      @param _currency The currency of the amount to base the ticket premine off of. 
      @param _beneficiary The address to send the printed tickets to.
      @param _memo A memo to leave with the printing.
      @param _preferUnstakedTickets If there is a preference to unstake the printed tickets.
/
    function printPreminedTickets(
        uint256 _projectId,
        uint25



### `printPreminedTickets(uint256 _projectId, uint256 _amount, uint256 _currency, address _beneficiary, string _memo, bool _preferUnstakedTickets)` (external)

t256(_processedTicketTrackerOf[_projectId]) +
                    uint256(_weightedAmount) <=
                uint256(type(int256).max),
            "TerminalV1::printTickets: INT_LIMIT_REACHED"
        );

        _processedTicketTrackerOf[_projectId] =
            _processedTicketTrackerOf[_projectId] +
            int256(_weightedAmount);

        // Set the count of preconfigure tickets this project has printed.
        _preconfigureTicketCountOf[_projectId] =
            _preconfigureTicketCountOf[_projectId] +
            _weightedAmount;

        // Print the project's tickets for the beneficiary.
        ticketBooth.print(
            _beneficiary,
            _projectId,
            _weightedAmount,
            _preferUnstakedTickets
        );

        emit PrintPre



### `pay(uint256 _projectId, address _beneficiary, string _memo, bool _preferUnstakedTickets) → uint256` (external)

eference to this project's current balance, including any earned yield.
        // Get the currency price of ETH.
        uint256 _ethPrice = prices.getETHPriceFor(_fundingCycle.currency);

        // Get the price of ETH.
        // The amount of ETH that is being tapped.
        uint256 _tappedWeiAmount = PRBMathUD60x18.div(_amount, _ethPrice);

        // The amount being tapped must be at least as much as was expected.
        require(
            _minReturnedWei <= _tappedWeiAmount,
            "TerminalV1::tap: INADEQUATE"
        );

        // Get a reference to this project's current balance, including an



### `tap(uint256 _projectId, uint256 _amount, uint256 _currency, uint256 _minReturnedWei) → uint256` (external)

wnerOf(_fundingCycle.projectId)
        );

        // Get a reference to the handle of the project paying the fee and sending payouts.
        bytes32 _handle = projects.handleOf(_projectId);

        // Take a fee from the _tappedWeiAmount, if needed.
        // The project's owner will be the beneficiary of the resulting printed tickets from the governance project.
        uint256 _feeAmount = _fundingCycle.fee > 0
            ? _takeFee(
                _tappedWeiAmount,
                _fundingCycle.fee,
                _projectOwner,



### `redeem(address _account, uint256 _projectId, uint256 _count, uint256 _minReturnedWei, address payable _beneficiary, bool _preferUnstaked) → uint256 amount` (external)

positive. Otherwise it will be negative.
        _processedTicketTrackerOf[_projectId] = _processedTicketTracker < 0 // If the tracker is negative, add the count and reverse it.
            ? -int256(uint256(-_processedTicketTracker) + _count) // the tracker is less than the count, subtract it from the count and reverse it.
            : _processedTicketTracker < int256(_count)
            ? -(int256(_count) - _processedTicketTracker) // simply subtract otherwise.
            : _processedTicketTracker - int256(_count);

        // Redeem the tickets, which burns them.
        ticketBooth.redeem(_account, _projectId, _count, _preferUnstaked);

        // Transfer funds to the specified address



### `migrate(uint256 _projectId, contract ITerminal _to)` (external)

low the zero address.
        require(
            _contract != ITerminal(address(0)),
            "TerminalV1::allowMigration: ZERO_ADDRESS"
        );

        // Can't migrate to this same contract
        require(_contract != this, "TerminalV1::allowMigration: NO_OP");

        // Set the contract as allowed



### `addToBalance(uint256 _projectId)` (external)

rminalV1::appointGovernance: ZERO_ADDRESS"
        );
        // The new governance can't be the same as the current governance.
        require(
            _pendingGovernance !=



### `allowMigration(contract ITerminal _contract)` (external)

e.
/
    function acceptGovernance() external override {
        // Only the pending governance address can accept.
        require(
            msg.sender == pendingGovernance,
            "TerminalV1::acceptGovernance: UNAUTHORI



### `setFee(uint256 _fee)` (external)

amount of tickets that are being printed.
/
    function printReservedTickets(uint256 _projectId)
        public
        override
        returns (uint256 amount)
    {
        // Get the current funding cycle to read the reserved rate from.
        FundingCycle memory _fundingCycle = fundingCycles.currentOf(_projectId);

        // If there's no funding cycle, there's no reserved tickets to print.



### `appointGovernance(address payable _pendingGovernance)` (external)

of tickets that need to be printed.
        // If there's no funding cycle, there's no tickets to print.
        // The reserved rate is in bits 8-15 of the metadata.
        amount = _reservedTicketAmountFrom(
            _processedTicketTrackerOf[_projectId],
            uint256(uint8(_fundingCycle.metadata >> 8)),
            _totalTicke



### `acceptGovernance()` (external)

verTicketAmount = _distributeToTicketMods(
            _fundingCycle,
            amount



### `printReservedTickets(uint256 _projectId) → uint256 amount` (public)

notice
      Pays out the mods for the specified funding cycle.

      @param _fundingCycle The funding cycle to base the distribution on.
      @param _amount The total amount being paid out.
      @param _memo A memo to send




