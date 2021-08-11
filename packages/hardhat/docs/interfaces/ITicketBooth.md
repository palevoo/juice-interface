## `ITicketBooth`






### `ticketsOf(uint256 _projectId) → contract ITickets` (external)





### `projects() → contract IProjects` (external)





### `lockedBalanceOf(address _holder, uint256 _projectId) → uint256` (external)





### `lockedBalanceBy(address _operator, address _holder, uint256 _projectId) → uint256` (external)





### `stakedBalanceOf(address _holder, uint256 _projectId) → uint256` (external)





### `stakedTotalSupplyOf(uint256 _projectId) → uint256` (external)





### `totalSupplyOf(uint256 _projectId) → uint256` (external)





### `balanceOf(address _holder, uint256 _projectId) → uint256 _result` (external)





### `issue(uint256 _projectId, string _name, string _symbol)` (external)





### `print(address _holder, uint256 _projectId, uint256 _amount, bool _preferUnstakedTickets)` (external)





### `redeem(address _holder, uint256 _projectId, uint256 _amount, bool _preferUnstaked)` (external)





### `stake(address _holder, uint256 _projectId, uint256 _amount)` (external)





### `unstake(address _holder, uint256 _projectId, uint256 _amount)` (external)





### `lock(address _holder, uint256 _projectId, uint256 _amount)` (external)





### `unlock(address _holder, uint256 _projectId, uint256 _amount)` (external)





### `transfer(address _holder, uint256 _projectId, uint256 _amount, address _recipient)` (external)






### `Issue(uint256 projectId, string name, string symbol, address caller)`





### `Print(address holder, uint256 projectId, uint256 amount, bool convertedTickets, bool preferUnstakedTickets, address controller)`





### `Redeem(address holder, uint256 projectId, uint256 amount, uint256 stakedTickets, bool preferUnstaked, address controller)`





### `Stake(address holder, uint256 projectId, uint256 amount, address caller)`





### `Unstake(address holder, uint256 projectId, uint256 amount, address caller)`





### `Lock(address holder, uint256 projectId, uint256 amount, address caller)`





### `Unlock(address holder, uint256 projectId, uint256 amount, address caller)`





### `Transfer(address holder, uint256 projectId, address recipient, uint256 amount, address caller)`





