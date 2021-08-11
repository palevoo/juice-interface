## `Prices`

Manage and normalizes ETH price feeds.




### `getETHPriceFor(uint256 _currency) → uint256` (external)


      Gets the current price of ETH for the provided currency.
      
      @param _currency The currency to get a price for.
      
      @return price The price of ETH with 18 decimals.



### `addFeed(contract AggregatorV3Interface _feed, uint256 _currency)` (external)


      Add a price feed for the price of ETH.

      @dev
      Current feeds can't be modified.

      @param _feed The price feed being added.
      @param _currency The currency that the price feed is for.




