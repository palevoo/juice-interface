## `IFundingCycles`






### `latestIdOf(uint256 _projectId) → uint256` (external)





### `count() → uint256` (external)





### `BASE_WEIGHT() → uint256` (external)





### `MAX_CYCLE_LIMIT() → uint256` (external)





### `get(uint256 _fundingCycleId) → struct FundingCycle` (external)





### `queuedOf(uint256 _projectId) → struct FundingCycle` (external)





### `currentOf(uint256 _projectId) → struct FundingCycle` (external)





### `currentBallotStateOf(uint256 _projectId) → enum BallotState` (external)





### `configure(uint256 _projectId, struct FundingCycleProperties _properties, uint256 _metadata, uint256 _fee, bool _configureActiveFundingCycle) → struct FundingCycle fundingCycle` (external)





### `tap(uint256 _projectId, uint256 _amount) → struct FundingCycle fundingCycle` (external)






### `Configure(uint256 fundingCycleId, uint256 projectId, uint256 reconfigured, struct FundingCycleProperties _properties, uint256 metadata, address caller)`





### `Tap(uint256 fundingCycleId, uint256 projectId, uint256 amount, uint256 newTappedAmount, address caller)`





### `Init(uint256 fundingCycleId, uint256 projectId, uint256 number, uint256 previous, uint256 weight, uint256 start)`





