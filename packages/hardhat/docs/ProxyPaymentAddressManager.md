## `ProxyPaymentAddressManager`

@notice
  Manages deploying proxy payment addresses for Juicebox projects.




### `constructor(contract ITerminalDirectory _terminalDirectory, contract ITicketBooth _ticketBooth)` (public)





### `addressesOf(uint256 _projectId) → contract IProxyPaymentAddress[]` (external)


      A list of all proxy payment addresses for the specified project ID.

      @param _projectId The ID of the project to get proxy payment addresses for.

      @return A list of proxy payment addresses for the specified project ID.



### `deploy(uint256 _projectId, string _memo) → address` (external)

Deploys a proxy payment address.
      @param _projectId ID of the project funds will be fowarded to.
      @param _memo Memo that will be attached withdrawal transactions.




