## `ITerminalV1`






### `governance() → address payable` (external)





### `pendingGovernance() → address payable` (external)





### `projects() → contract IProjects` (external)





### `fundingCycles() → contract IFundingCycles` (external)





### `ticketBooth() → contract ITicketBooth` (external)





### `prices() → contract IPrices` (external)





### `modStore() → contract IModStore` (external)





### `reservedTicketBalanceOf(uint256 _projectId, uint256 _reservedRate) → uint256` (external)





### `canPrintPreminedTickets(uint256 _projectId) → bool` (external)





### `balanceOf(uint256 _projectId) → uint256` (external)





### `currentOverflowOf(uint256 _projectId) → uint256` (external)





### `claimableOverflowOf(address _account, uint256 _amount, uint256 _projectId) → uint256` (external)





### `fee() → uint256` (external)





### `deploy(address _owner, bytes32 _handle, string _uri, struct FundingCycleProperties _properties, struct FundingCycleMetadata _metadata, struct PayoutMod[] _payoutMods, struct TicketMod[] _ticketMods)` (external)





### `configure(uint256 _projectId, struct FundingCycleProperties _properties, struct FundingCycleMetadata _metadata, struct PayoutMod[] _payoutMods, struct TicketMod[] _ticketMods) → uint256` (external)





### `printPreminedTickets(uint256 _projectId, uint256 _amount, uint256 _currency, address _beneficiary, string _memo, bool _preferUnstakedTickets)` (external)





### `tap(uint256 _projectId, uint256 _amount, uint256 _currency, uint256 _minReturnedWei) → uint256` (external)





### `redeem(address _account, uint256 _projectId, uint256 _amount, uint256 _minReturnedWei, address payable _beneficiary, bool _preferUnstaked) → uint256 returnAmount` (external)





### `printReservedTickets(uint256 _projectId) → uint256 reservedTicketsToPrint` (external)





### `setFee(uint256 _fee)` (external)





### `appointGovernance(address payable _pendingGovernance)` (external)





### `acceptGovernance()` (external)






### `Configure(uint256 fundingCycleId, uint256 projectId, address caller)`





### `Tap(uint256 fundingCycleId, uint256 projectId, address beneficiary, uint256 amount, uint256 currency, uint256 netTransferAmount, uint256 beneficiaryTransferAmount, uint256 govFeeAmount, address caller)`





### `Redeem(address holder, address beneficiary, uint256 _projectId, uint256 amount, uint256 returnAmount, address caller)`





### `PrintReserveTickets(uint256 fundingCycleId, uint256 projectId, address beneficiary, uint256 count, uint256 beneficiaryTicketAmount, address caller)`





### `DistributeToPayoutMod(uint256 fundingCycleId, uint256 projectId, struct PayoutMod mod, uint256 modCut, address caller)`





### `DistributeToTicketMod(uint256 fundingCycleId, uint256 projectId, struct TicketMod mod, uint256 modCut, address caller)`





### `AppointGovernance(address governance)`





### `AcceptGovernance(address governance)`





### `PrintPreminedTickets(uint256 projectId, address beneficiary, uint256 amount, uint256 currency, string memo, address caller)`





### `Deposit(uint256 amount)`





### `EnsureTargetLocalWei(uint256 target)`





### `SetYielder(contract IYielder newYielder)`





### `SetFee(uint256 _amount)`





### `SetTargetLocalWei(uint256 amount)`





