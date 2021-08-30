// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./interfaces/ITerminal.sol";
import "./interfaces/IPrices.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/IGovernable.sol";
import "./abstract/JuiceboxProject.sol";

/// Owner should eventually change to a multisig wallet contract.
contract Governance is JuiceboxProject, IGovernance {
    // --- external transactions --- //

    constructor(uint256 _projectId, ITerminalDirectory _terminalDirectory)
        JuiceboxProject(_projectId, _terminalDirectory)
    {}

    /** 
      @notice Gives projects using one Terminal access to migrate to another Terminal.
      @param _from The terminal to allow a new migration from.
      @param _to The terminal to allow migration to.
    */
    function allowMigration(ITerminal _from, ITerminal _to) external onlyOwner {
        _from.allowMigration(_to);
    }

    /**
        @notice Adds a price feed.
        @param _prices The prices contract to add a feed to.
        @param _feed The price feed to add.
        @param _currency The currency the price feed is for.
    */
    function addPriceFeed(
        IPrices _prices,
        AggregatorV3Interface _feed,
        uint256 _currency
    ) external onlyOwner {
        _prices.addFeed(_feed, _currency);
    }

    /** 
      @notice Appoints a new governance for the specified terminalV1.
      @param _governable The governable contract to change the governance of.
      @param _newGovernance The address to appoint as governance.
    */
    function transferGovernance(IGovernable _governable, address _newGovernance)
        external
        override
        onlyOwner
    {
        _governable.transferGovernance(_newGovernance);
    }
}
