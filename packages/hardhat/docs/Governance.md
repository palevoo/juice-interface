## `Governance`

Owner should eventually change to a multisig wallet contract.




### `constructor(uint256 _projectId, contract ITerminalDirectory _terminalDirectory)` (public)





### `allowMigration(contract ITerminal _from, contract ITerminal _to)` (external)

Gives projects using one Terminal access to migrate to another Terminal.
      @param _from The terminal to allow a new migration from.
      @param _to The terminal to allow migration to.



### `addPriceFeed(contract IPrices _prices, contract AggregatorV3Interface _feed, uint256 _currency)` (external)

Adds a price feed.
        @param _prices The prices contract to add a feed to.
        @param _feed The price feed to add.
        @param _currency The currency the price feed is for.



### `setFee(contract ITerminalV1 _terminalV1, uint256 _fee)` (external)

Sets the fee of the TerminalV1.
      @param _terminalV1 The terminalV1 to change the fee of.
      @param _fee The new fee.



### `appointGovernance(contract ITerminalV1 _terminalV1, address payable _newGovernance)` (external)

Appoints a new governance for the specified terminalV1.
      @param _terminalV1 The terminalV1 to change the governance of.
      @param _newGovernance The address to appoint as governance.



### `acceptGovernance(contract ITerminalV1 _terminalV1)` (external)

Accepts the offer to be the governance of a new terminalV1.
      @param _terminalV1 The terminalV1 to change the governance of.




