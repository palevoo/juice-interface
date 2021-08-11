## `ProxyPaymentAddress`

@notice
  A contract that can receive and hold funds for a given project.
  Once funds are tapped, tickets are printed and can be transferred out of the contract at a later date.

  Particularly useful for routing funds from third-party platforms (e.g., Open Sea).




### `constructor(contract ITerminalDirectory _terminalDirectory, contract ITicketBooth _ticketBooth, uint256 _projectId, string _memo)` (public)





### `receive()` (external)





### `tap()` (external)





### `transferTickets(address _beneficiary, uint256 _amount)` (external)

Transfers tickets held by this contract to a beneficiary.
      @param _beneficiary Address of the beneficiary tickets will be transferred to.




