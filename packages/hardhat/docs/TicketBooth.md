## `TicketBooth`


  Manage Ticket printing, redemption, and account balances.

  @dev
  Tickets can be either represented internally staked, or as unstaked ERC-20s.
  This contract manages these two representations and the conversion between the two.

  @dev
  The total supply of a project's tickets and the balance of each account are calculated in this contract.




### `totalSupplyOf(uint256 _projectId) → uint256 supply` (external)


      The total supply of tickets for each project, including staked and unstaked tickets.

      @param _projectId The ID of the project to get the total supply of.

      @return supply The total supply.



### `balanceOf(address _holder, uint256 _projectId) → uint256 balance` (external)


      The total balance of tickets a holder has for a specified project, including staked and unstaked tickets.

      @param _holder The ticket holder to get a balance for.
      @param _projectId The project to get the `_hodler`s balance of.

      @return balance The balance.



### `constructor(contract IProjects _projects, contract IOperatorStore _operatorStore, contract ITerminalDirectory _terminalDirectory)` (public)





### `issue(uint256 _projectId, string _name, string _symbol)` (external)


        Issues an owner's ERC-20 Tickets that'll be used when unstaking tickets.

        @dev 
        Deploys an owner's Ticket ERC-20 token contract.

        @param _projectId The ID of the project being issued tickets.
        @param _name The ERC-20's name. " Juicebox ticket" will be appended.
        @param _symbol The ERC-20's symbol. "j" will be prepended.



### `print(address _holder, uint256 _projectId, uint256 _amount, bool _preferUnstakedTickets)` (external)


      Print new tickets.

      @dev
      Only a project's current terminal can print its tickets.

      @param _holder The address receiving the new tickets.
      @param _projectId The project to which the tickets belong.
      @param _amount The amount to print.
      @param _preferUnstakedTickets Whether ERC20's should be converted automatically if they have been issued.



### `redeem(address _holder, uint256 _projectId, uint256 _amount, bool _preferUnstaked)` (external)


      Redeems tickets.

      @dev
      Only a project's current terminal can redeem its tickets.

      @param _holder The address that owns the tickets being redeemed.
      @param _projectId The ID of the project of the tickets being redeemed.
      @param _amount The amount of tickets being redeemed.
      @param _preferUnstaked If the preference is to redeem tickets that have been converted to ERC-20s.



### `stake(address _holder, uint256 _projectId, uint256 _amount)` (external)


      Stakes ERC20 tickets by burning their supply and creating an internal staked version.

      @dev
      Only a ticket holder or an operator can stake its tickets.

      @param _holder The owner of the tickets to stake.
      @param _projectId The ID of the project whos tickets are being staked.
      @param _amount The amount of tickets to stake.



### `unstake(address _holder, uint256 _projectId, uint256 _amount)` (external)


      Unstakes internal tickets by creating and distributing ERC20 tickets.

      @dev
      Only a ticket holder or an operator can unstake its tickets.

      @param _holder The owner of the tickets to unstake.
      @param _projectId The ID of the project whos tickets are being unstaked.
      @param _amount The amount of tickets to unstake.



### `lock(address _holder, uint256 _projectId, uint256 _amount)` (external)


      Lock a project's tickets, preventing them from being redeemed and from converting to ERC20s.

      @dev
      Only a ticket holder or an operator can lock its tickets.

      @param _holder The holder to lock tickets from.
      @param _projectId The ID of the project whos tickets are being locked.
      @param _amount The amount of tickets to lock.



### `unlock(address _holder, uint256 _projectId, uint256 _amount)` (external)


      Unlock a project's tickets.

      @dev
      The address that locked the tickets must be the address that unlocks the tickets.

      @param _holder The holder to unlock tickets from.
      @param _projectId The ID of the project whos tickets are being unlocked.
      @param _amount The amount of tickets to unlock.



### `transfer(address _holder, uint256 _projectId, uint256 _amount, address _recipient)` (external)


      Allows a ticket holder to transfer its tickets to another account, without unstaking to ERC-20s.

      @dev
      Only a ticket holder or an operator can transfer its tickets.

      @param _holder The holder to transfer tickets from.
      @param _projectId The ID of the project whos tickets are being transfered.
      @param _amount The amount of tickets to transfer.
      @param _recipient The recipient of the tickets.




