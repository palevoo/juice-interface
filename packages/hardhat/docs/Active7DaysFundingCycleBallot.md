## `Active7DaysFundingCycleBallot`

Manages votes towards approving funding cycle reconfigurations.




### `duration() → uint256` (external)

The time that this ballot is active for.
      @dev A ballot should not be considered final until the duration has passed.
      @return The durection in seconds.



### `state(uint256, uint256 _configured) → enum BallotState` (external)

The approval state of a particular funding cycle.
      @param _configured The configuration of the funding cycle to check the state of.
      @return The state of the provided ballot.




