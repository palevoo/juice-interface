## `FundingCycles`

Manage funding cycle configurations, accounting, and scheduling.




### `get(uint256 _fundingCycleId) → struct FundingCycle` (external)


        Get the funding cycle with the given ID.

        @param _fundingCycleId The ID of the funding cycle to get.

        @return _fundingCycle The funding cycle.



### `queuedOf(uint256 _projectId) → struct FundingCycle` (external)


        The funding cycle that's next up for a project, and therefor not currently accepting payments.

        @dev 
        This runs roughly similar logic to `_configurable`.

        @param _projectId The ID of the project being looked through.

        @return _fundingCycle The queued funding cycle.



### `currentOf(uint256 _projectId) → struct FundingCycle fundingCycle` (external)


        The funding cycle that is currently active for the specified project.

        @dev 
        This runs very similar logic to `_tappable`.

        @param _projectId The ID of the project being looked through.

        @return fundingCycle The current funding cycle.



### `currentBallotStateOf(uint256 _projectId) → enum BallotState` (external)


      The currency ballot state of the project.

      @param _projectId The ID of the project to check for a pending reconfiguration.

      @return The current ballot's state.



### `constructor(contract ITerminalDirectory _terminalDirectory)` (public)





### `configure(uint256 _projectId, struct FundingCycleProperties _properties, uint256 _metadata, uint256 _fee, bool _configureActiveFundingCycle) → struct FundingCycle fundingCycle` (external)


        Configures the next eligible funding cycle for the specified project.

        @dev
        Only a project's current terminal can configure its funding cycles.

        @param _projectId The ID of the project being reconfigured.
        @param _properties The funding cycle configuration.
          @dev _properties.target The amount that the project wants to receive in each funding cycle. 18 decimals.
          @dev _properties.currency The currency of the `_target`. Send 0 for ETH or 1 for USD.
          @dev _properties.duration The duration of the funding cycle for which the `_target` amount is needed. Measured in days. 
            Set to 0 for no expiry and to be able to reconfigure anytime.
          @dev _cycleLimit The number of cycles that this configuration should last for before going back to the last permanent. This does nothing for a project's first funding cycle.
          @dev _properties.discountRate A number from 0-200 indicating how valuable a contribution to this funding cycle is compared to previous funding cycles.
            If it's 0, each funding cycle will have equal weight.
            If the number is 100, a contribution to the next funding cycle will only give you 90% of tickets given to a contribution of the same amount during the current funding cycle.
            If the number is 200, a contribution to the next funding cycle will only give you 80% of tickets given to a contribution of the same amoutn during the current funding cycle.
            If the number is 201, an non-recurring funding cycle will get made.
          @dev _ballot The new ballot that will be used to approve subsequent reconfigurations.
        @param _metadata Data to associate with this funding cycle configuration.
        @param _fee The fee that this configuration will incure when tapping.
        @param _configureActiveFundingCycle If a funding cycle that has already started should be configurable.

        @return fundingCycle The funding cycle that the configuration will take effect during.



### `tap(uint256 _projectId, uint256 _amount) → struct FundingCycle fundingCycle` (external)


      Tap funds from a project's currently tappable funding cycle.

      @dev
      Only a project's current terminal can tap funds for its funding cycles.

      @param _projectId The ID of the project being tapped.
      @param _amount The amount being tapped.

      @return fundingCycle The tapped funding cycle.



### `_mockFundingCycleBasedOn(struct FundingCycle _baseFundingCycle, bool _allowMidCycle) → struct FundingCycle` (internal)


        A view of the funding cycle that would be created based on the provided one if the project doesn't make a reconfiguration.

        @param _baseFundingCycle The funding cycle to make the calculation for.
        @param _allowMidCycle Allow the mocked funding cycle to already be mid cycle.

        @return The next funding cycle, with an ID set to 0.



### `_deriveStart(struct FundingCycle _baseFundingCycle, struct FundingCycle _latestPermanentFundingCycle, uint256 _mustStartOnOrAfter) → uint256 start` (internal)


        The date that is the nearest multiple of the specified funding cycle's duration from its end.

        @param _baseFundingCycle The funding cycle to make the calculation for.
        @param _latestPermanentFundingCycle The latest funding cycle in the same project as `_baseFundingCycle` to not have a limit.
        @param _mustStartOnOrAfter A date that the derived start must be on or come after.

        @return start The next start time.



### `_deriveWeight(struct FundingCycle _baseFundingCycle, struct FundingCycle _latestPermanentFundingCycle, uint256 _start) → uint256 weight` (internal)


        The accumulated weight change since the specified funding cycle.

        @param _baseFundingCycle The funding cycle to make the calculation with.
        @param _latestPermanentFundingCycle The latest funding cycle in the same project as `_fundingCycle` to not have a limit.
        @param _start The start time to derive a weight for.

        @return weight The next weight.



### `_deriveNumber(struct FundingCycle _baseFundingCycle, struct FundingCycle _latestPermanentFundingCycle, uint256 _start) → uint256 number` (internal)


        The number of the next funding cycle given the specified funding cycle.

        @param _baseFundingCycle The funding cycle to make the calculation with.
        @param _latestPermanentFundingCycle The latest funding cycle in the same project as `_fundingCycle` to not have a limit.
        @param _start The start time to derive a number for.

        @return number The next number.



### `_deriveCycleLimit(struct FundingCycle _fundingCycle, uint256 _start) → uint256` (internal)


        The limited number of times a funding cycle configuration can be active given the specified funding cycle.

        @param _fundingCycle The funding cycle to make the calculation with.
        @param _start The start time to derive cycles remaining for.

        @return start The inclusive nunmber of cycles remaining.




