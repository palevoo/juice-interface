## `OperatorStore`

@notice
  Addresses can give permissions to any other address to take specific actions 
  throughout the Juicebox ecosystem on their behalf. These addresses are called `operators`.
  
  @dev
  Permissions are stored as a uint256, with each boolean bit representing whether or not
  an oporator has the permission identified by that bit's index in the 256 bit uint256.
  Indexes must be between 0 and 255.

  The directory of permissions, along with how they uniquely mapp to indexes, are managed externally.
  This contract doesn't know or care about specific permissions and their indexes.




### `hasPermission(address _operator, address _account, uint256 _domain, uint256 _permissionIndex) → bool` (external)


      Whether or not an operator has the permission to take a certain action pertaining to the specified domain.

      @param _operator The operator to check.
      @param _account The account that has given out permission to the operator.
      @param _domain The domain that the operator has been given permissions to operate.
      @param _permissionIndex the permission to check for.

      @return Whether the operator has the specified permission.



### `hasPermissions(address _operator, address _account, uint256 _domain, uint256[] _permissionIndexes) → bool` (external)


      Whether or not an operator has the permission to take certain actions pertaining to the specified domain.

      @param _operator The operator to check.
      @param _account The account that has given out permissions to the operator.
      @param _domain The domain that the operator has been given permissions to operate.
      @param _permissionIndexes An array of permission indexes to check for.

      @return Whether the operator has all specified permissions.



### `setOperator(address _operator, uint256 _domain, uint256[] _permissionIndexes)` (external)


      Sets permissions for an operator.

      @param _operator The operator to give permission to.
      @param _domain The domain that the operator is being given permissions to operate.
      @param _permissionIndexes An array of indexes of permissions to set.



### `setOperators(address[] _operators, uint256[] _domains, uint256[][] _permissionIndexes)` (external)


      Sets permissions for many operators.

      @param _operators The operators to give permission to.
      @param _domains The domains that can be operated. Set to 0 to allow operation of account level actions.
      @param _permissionIndexes The level of power each operator should have.




