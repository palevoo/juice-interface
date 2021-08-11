## `ITerminalDirectory`






### `projects() → contract IProjects` (external)





### `terminalOf(uint256 _projectId) → contract ITerminal` (external)





### `beneficiaryOf(address _account) → address` (external)





### `unstakedTicketsPreferenceOf(address _account) → bool` (external)





### `addressesOf(uint256 _projectId) → contract IDirectPaymentAddress[]` (external)





### `deployAddress(uint256 _projectId, string _memo)` (external)





### `setTerminal(uint256 _projectId, contract ITerminal _terminal)` (external)





### `setPayerPreferences(address _beneficiary, bool _preferUnstakedTickets)` (external)






### `DeployAddress(uint256 projectId, string memo, address caller)`





### `SetTerminal(uint256 projectId, contract ITerminal terminal, address caller)`





### `SetPayerPreferences(address account, address beneficiary, bool preferUnstakedTickets)`





