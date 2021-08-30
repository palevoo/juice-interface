// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./../interfaces/IGovernable.sol";

abstract contract Governable is IGovernable {
    // Modifier to only allow governance to call the function.
    modifier onlyGov() {
        require(msg.sender == governance, "TerminalV2: UNAUTHORIZED");
        _;
    }

    /// @notice The governance of the contract who makes fees and can allow new terminal contracts to be migrated to by project owners.
    address public override governance;

    /** 
      @param _governance A contract that governs this contract.
    */
    constructor(address _governance) {
        governance = _governance;
    }

    /** 
      @notice 
      Allows governance to transfer its privileges to another contract.

      @dev
      Only the current governance can transer power to a new governance.

      @param _newGovernance The governance to transition power to. 
    */
    function transferGovernance(address _newGovernance)
        external
        override
        onlyGov
    {
        // The new governance can't be the zero address.
        require(
            _newGovernance != address(0),
            "TerminalV1::transferGovernance: ZERO_ADDRESS"
        );

        // Set the govenance to the new value.
        governance = _newGovernance;

        emit TransferGovernance(_newGovernance);
    }
}
