// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IJBPrices.sol";

/** 
  @notice Manage and normalizes ETH price feeds.
*/
contract JBPrices is IJBPrices, Ownable {
    // --- public constant stored properties --- //

    /// @notice The target number of decimals the price feed results have.
    uint256 public constant override targetDecimals = 18;

    // --- public stored properties --- //

    /// @notice The number to multiply each price feed by to get to the target decimals.
    mapping(uint256 => mapping(uint256 => uint256))
        public
        override feedDecimalAdjuster;

    /// @notice The available price feeds that can be used to get the price of ETH.
    mapping(uint256 => mapping(uint256 => AggregatorV3Interface))
        public
        override feedFor;

    // --- external views --- //

    /** 
      @notice 
      Gets the current price of ETH for the provided currency.
      
      @param _currency The currency to get a price for.
      
      @return price The price of ETH with 18 decimals.
    */
    function getPriceFor(uint256 _currency, uint256 _base)
        external
        view
        override
        returns (uint256)
    {
        // The currency is the base, return 1.
        if (_currency == _base) return 10**targetDecimals;

        // Get a reference to the feed.
        AggregatorV3Interface _feed = feedFor[_currency][_base];

        // Feed must exist.
        require(
            _feed != AggregatorV3Interface(address(0)),
            "Prices::getETHPrice: NOT_FOUND"
        );

        // Get the latest round information. Only need the price is needed.
        (, int256 _price, , , ) = _feed.latestRoundData();

        // Multiply the price by the decimal adjuster to get the normalized result.
        return uint256(_price) * feedDecimalAdjuster[_currency][_base];
    }

    // --- external transactions --- //

    /** 
      @notice 
      Add a price feed for a currency in terms of the provided base currency.

      @dev
      Current feeds can't be modified.

      @param _currency The currency that the price feed is for.
      @param _base The currency that the price feed is based on.
      @param _feed The price feed being added.
    */
    function addFeedFor(
        uint256 _currency,
        uint256 _base,
        AggregatorV3Interface _feed
    ) external override onlyOwner {
        // There can't already be a feed for the specified currency.
        require(
            feedFor[_currency][_base] == AggregatorV3Interface(address(0)),
            "Prices::addFeedFor: ALREADY_EXISTS"
        );

        // Get a reference to the number of decimals the feed uses.
        uint256 _decimals = _feed.decimals();

        // Decimals should be less than or equal to the target number of decimals.
        require(
            _decimals <= targetDecimals,
            "Prices::addFeedFor: BAD_DECIMALS"
        );

        // Set the feed.
        feedFor[_currency][_base] = _feed;

        // Set the decimal adjuster for the currency.
        feedDecimalAdjuster[_currency][_base] =
            10**(targetDecimals - _decimals);

        emit AddFeed(_currency, _base, _decimals, _feed);
    }
}
