## `IProjects`






### `count() → uint256` (external)





### `uriOf(uint256 _projectId) → string` (external)





### `handleOf(uint256 _projectId) → bytes32 handle` (external)





### `projectFor(bytes32 _handle) → uint256 projectId` (external)





### `transferAddressFor(bytes32 _handle) → address receiver` (external)





### `challengeExpiryOf(bytes32 _handle) → uint256` (external)





### `exists(uint256 _projectId) → bool` (external)





### `create(address _owner, bytes32 _handle, string _uri, contract ITerminal _terminal) → uint256 id` (external)





### `setHandle(uint256 _projectId, bytes32 _handle)` (external)





### `setUri(uint256 _projectId, string _uri)` (external)





### `transferHandle(uint256 _projectId, address _to, bytes32 _newHandle) → bytes32 _handle` (external)





### `claimHandle(bytes32 _handle, address _for, uint256 _projectId)` (external)






### `Create(uint256 projectId, address owner, bytes32 handle, string uri, contract ITerminal terminal, address caller)`





### `SetHandle(uint256 projectId, bytes32 handle, address caller)`





### `SetUri(uint256 projectId, string uri, address caller)`





### `TransferHandle(uint256 projectId, address to, bytes32 handle, bytes32 newHandle, address caller)`





### `ClaimHandle(address account, uint256 projectId, bytes32 handle, address caller)`





### `ChallengeHandle(bytes32 handle, uint256 challengeExpiry, address caller)`





### `RenewHandle(bytes32 handle, uint256 projectId, address caller)`





