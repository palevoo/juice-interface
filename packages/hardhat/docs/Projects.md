## `Projects`


  Stores project ownership and identifying information.

  @dev
  Projects are represented as ERC-721's.




### `exists(uint256 _projectId) → bool` (external)


      Whether the specified project exists.

      @param _projectId The project to check the existence of.

      @return A flag indicating if the project exists.



### `constructor(contract IOperatorStore _operatorStore)` (public)





### `create(address _owner, bytes32 _handle, string _uri, contract ITerminal _terminal) → uint256` (external)


        Create a new project.

        @dev 
        Anyone can create a project on an owner's behalf.

        @param _owner The owner of the project.
        @param _handle A unique handle for the project.
        @param _uri An ipfs CID to more info about the project.
        @param _terminal The terminal to set for this project so that it can start receiving payments.

        @return The new project's ID.



### `setHandle(uint256 _projectId, bytes32 _handle)` (external)


      Allows a project owner to set the project's handle.

      @dev 
      Only a project's owner or operator can set its handle.

      @param _projectId The ID of the project.
      @param _handle The new unique handle for the project.



### `setUri(uint256 _projectId, string _uri)` (external)


      Allows a project owner to set the project's uri.

      @dev 
      Only a project's owner or operator can set its uri.

      @param _projectId The ID of the project.
      @param _uri An ipfs CDN to more info about the project. Don't include the leading ipfs://



### `transferHandle(uint256 _projectId, address _to, bytes32 _newHandle) → bytes32 _handle` (external)


      Allows a project owner to transfer its handle to another address.

      @dev 
      Only a project's owner or operator can transfer its handle.

      @param _projectId The ID of the project to transfer the handle from.
      @param _to The address that can now reallocate the handle.
      @param _newHandle The new unique handle for the project that will replace the transfered one.



### `claimHandle(bytes32 _handle, address _for, uint256 _projectId)` (external)


      Allows an address to claim and handle that has been transfered to them and apply it to a project of theirs.

      @dev 
      Only a project's owner or operator can claim a handle onto it.

      @param _handle The handle being claimed.
      @param _for The address that the handle has been transfered to.
      @param _projectId The ID of the project to use the claimed handle.



### `challengeHandle(bytes32 _handle)` (external)

@notice
      Allows anyone to challenge a project's handle. After one year, the handle can be claimed by the public if the challenge isn't answered by the handle's project.
      This can be used to make sure a handle belonging to an unattended to project isn't lost forever.

      @param _handle The handle to challenge.



### `renewHandle(uint256 _projectId)` (external)

@notice
      Allows a project to renew its handle so it can't be claimed until a year after its challenged again.

      @dev 
      Only a project's owner or operator can renew its handle.

      @param _projectId The ID of the project that current has the handle being renewed.




