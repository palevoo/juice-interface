## `Shwotime`




  Shwotime allows friends to commit to buying tickets to events together.
  They can commit to buying a ticket if a specified list of addresses also commit to buy the ticket.

  Not reliable for situations where networks dont entirely overlap.


### `constructor(uint256 _projectId, contract ITerminalDirectory _terminalDirectory, contract IERC20 _dai, uint256 _fee)` (public)





### `createTickets(uint256 _price, uint256 _max, uint256 _expiry)` (external)





### `buyTicket(uint256 id, address[] addresses)` (external)





### `collect(uint256 _id, string _memo)` (external)






