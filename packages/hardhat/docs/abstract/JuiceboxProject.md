## `JuiceboxProject`

A contract that inherits from JuiceboxProject can use Juicebox as a business-model-as-a-service.
  @dev The owner of the contract makes admin decisions such as:
    - Which address is the funding cycle owner, which can tap funds from the funding cycle.
    - Should this project's Tickets be migrated to a new TerminalV1.




### `constructor(uint256 _projectId, contract ITerminalDirectory _terminalDirectory)` (internal)





### `receive()` (external)





### `withdraw(address payable _beneficiary, uint256 _amount)` (external)

Withdraws funds stored in this contract.
      @param _beneficiary The address to send the funds to.
      @param _amount The amount to send.



### `setProjectId(uint256 _projectId)` (external)

Allows the project that is being managed to be set.
      @param _projectId The ID of the project that is being managed.



### `pay(address _beneficiary, string _memo, bool _preferUnstakedTickets)` (external)

Make a payment to this project.
      @param _beneficiary The address who will receive tickets from this fee.
      @param _memo A memo that will be included in the published event.
      @param _preferUnstakedTickets Whether ERC20's should be claimed automatically if they have been issued.



### `transferProjectOwnership(contract IProjects _projects, address _newOwner, uint256 _projectId, bytes _data)` (external)

Transfer the ownership of the project to a new owner.  
        @dev This contract will no longer be able to reconfigure or tap funds from this project.
        @param _projects The projects contract.
        @param _newOwner The new project owner.
        @param _projectId The ID of the project to transfer ownership of.
        @param _data Arbitrary data to include in the transaction.



### `onERC721Received(address, address, uint256, bytes) → bytes4` (public)

Allows this contract to receive a project.



### `setOperator(contract IOperatorStore _operatorStore, address _operator, uint256 _projectId, uint256[] _permissionIndexes)` (external)





### `setOperators(contract IOperatorStore _operatorStore, address[] _operators, uint256[] _projectIds, uint256[][] _permissionIndexes)` (external)





### `_takeFee(uint256 _amount, address _beneficiary, string _memo, bool _preferUnstakedTickets)` (internal)

Take a fee for this project from this contract.
      @param _amount The payment amount.
      @param _beneficiary The address who will receive tickets from this fee.
      @param _memo A memo that will be included in the published event.
      @param _preferUnstakedTickets Whether ERC20's should be claimed automatically if they have been issued.




