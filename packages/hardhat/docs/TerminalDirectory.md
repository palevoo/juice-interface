## `TerminalDirectory`

@notice
  Allows project owners to deploy proxy contracts that can pay them when receiving funds directly.




### `addressesOf(uint256 _projectId) → contract IDirectPaymentAddress[]` (external)


      A list of all direct payment addresses for the specified project ID.

      @param _projectId The ID of the project to get direct payment addresses for.

      @return A list of direct payment addresses for the specified project ID.



### `constructor(contract IProjects _projects, contract IOperatorStore _operatorStore)` (public)





### `deployAddress(uint256 _projectId, string _memo)` (external)


      Allows anyone to deploy a new direct payment address for a project.

      @param _projectId The ID of the project to deploy a direct payment address for.
      @param _memo The note to use for payments made through the new direct payment address.



### `setTerminal(uint256 _projectId, contract ITerminal _terminal)` (external)


      Update the juicebox terminal that payments to direct payment addresses will be forwarded for the specified project ID.

      @param _projectId The ID of the project to set a new terminal for.
      @param _terminal The new terminal to set.



### `setPayerPreferences(address _beneficiary, bool _preferUnstakedTickets)` (external)


      Allows any address to pre set the beneficiary of their payments to any direct payment address,
      and to pre set whether to prefer to unstake tickets into ERC20's when making a payment.

      @param _beneficiary The beneficiary to set.
      @param _preferUnstakedTickets The preference to set.




