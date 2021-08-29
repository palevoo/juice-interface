/** 
  The governance of the TerminalV1 can transfer its power to a new address.
  To do so, the governance must appoint a new address, and that address must accept the appointment.
*/
module.exports = [
  {
    description: "The initial governance can set a new fee",
    fn: ({ executeFn, deployer, contracts, randomBigNumberFn, constants }) =>
      executeFn({
        caller: deployer,
        contract: contracts.governance,
        fn: "setFee",
        args: [
          contracts.terminalV1.address,
          randomBigNumberFn({ max: constants.MaxPercent })
        ]
      })
  },
  {
    description: "Appoint a new governance",
    fn: async ({ executeFn, deployer, contracts, randomSignerFn }) => {
      // Appoint a governance with a different address.
      const firstAppointedGovernance = randomSignerFn();

      await executeFn({
        caller: deployer,
        contract: contracts.governance,
        fn: "appointGovernance",
        args: [contracts.terminalV1.address, firstAppointedGovernance.address]
      });
      return { firstAppointedGovernance };
    }
  },
  {
    description: "The appointed governance shouldn't yet be able to set a fee",
    fn: ({
      executeFn,
      contracts,
      randomBigNumberFn,
      constants,
      local: { firstAppointedGovernance }
    }) =>
      executeFn({
        caller: firstAppointedGovernance,
        contract: contracts.terminalV1,
        fn: "setFee",
        args: [randomBigNumberFn({ max: constants.MaxPercent })],
        revert: "TerminalV1: UNAUTHORIZED"
      })
  },
  {
    description: "The current governance should still be able to set a fee",
    fn: ({ executeFn, deployer, contracts, randomBigNumberFn, constants }) =>
      executeFn({
        caller: deployer,
        contract: contracts.governance,
        fn: "setFee",
        args: [
          contracts.terminalV1.address,
          randomBigNumberFn({ max: constants.MaxPercent })
        ]
      })
  },
  {
    description: "Appoint a different governance",
    fn: async ({ executeFn, deployer, contracts, randomSignerFn }) => {
      // Appoint another governance with yet another address.
      const secondAppointedGovernance = randomSignerFn();
      await executeFn({
        caller: deployer,
        contract: contracts.governance,
        fn: "appointGovernance",
        args: [contracts.terminalV1.address, secondAppointedGovernance.address]
      });
      return { secondAppointedGovernance };
    }
  },
  {
    description:
      "If they're different, the first appointed governance should no longer be able to accept",
    fn: ({
      executeFn,
      contracts,
      local: { firstAppointedGovernance, secondAppointedGovernance }
    }) =>
      executeFn({
        caller: firstAppointedGovernance,
        contract: contracts.terminalV1,
        fn: "acceptGovernance",
        args: [],
        revert:
          firstAppointedGovernance.address !==
            secondAppointedGovernance.address &&
          "TerminalV1::acceptGovernance: UNAUTHORIZED"
      })
  },
  {
    description: "Accept a new governance",
    fn: ({ executeFn, contracts, local: { secondAppointedGovernance } }) =>
      executeFn({
        caller: secondAppointedGovernance,
        contract: contracts.terminalV1,
        fn: "acceptGovernance",
        args: []
      })
  },
  {
    description: "The old governance should no longer be able to set a fee",
    fn: ({
      executeFn,
      deployer,
      contracts,
      randomBigNumberFn,
      constants,
      local: { secondAppointedGovernance }
    }) =>
      executeFn({
        caller: deployer,
        contract: contracts.governance,
        fn: "setFee",
        args: [
          contracts.terminalV1.address,
          randomBigNumberFn({ max: constants.MaxPercent })
        ],
        revert:
          contracts.governance.address !== secondAppointedGovernance.address &&
          "TerminalV1: UNAUTHORIZED"
      })
  },
  {
    description: "The new governance should be able to set a fee",
    fn: ({
      executeFn,
      randomBigNumberFn,
      constants,
      contracts,
      local: { secondAppointedGovernance }
    }) =>
      executeFn({
        caller: secondAppointedGovernance,
        contract: contracts.terminalV1,
        fn: "setFee",
        args: [randomBigNumberFn({ max: constants.MaxPercent })]
      })
  },
  {
    description:
      "New governance should be able to appoint the old governance back",
    fn: ({ executeFn, contracts, local: { secondAppointedGovernance } }) =>
      executeFn({
        caller: secondAppointedGovernance,
        contract: contracts.terminalV1,
        fn: "appointGovernance",
        args: [contracts.governance.address]
      })
  },
  {
    description: "The owner should be the original project deployer",
    fn: ({ contracts, checkFn, randomSignerFn, constants }) => {
      checkFn({
        caller: randomSignerFn(),
        contract: contracts.projects,
        fn: "ownerOf",
        args: [constants.GovernanceProjectId],
        expect: constants.ProjectOwner.address
      });
    }
  },
  {
    description: "Transfer the project to another address",
    fn: async ({
      executeFn,
      contracts,
      constants,
      randomSignerFn,
      randomBytesFn
    }) => {
      const temporaryOwner = randomSignerFn({
        exclude: [constants.GovernanceOwner.address]
      });
      await executeFn({
        caller: constants.GovernanceOwner,
        contract: contracts.governance,
        fn: "transferProjectOwnership",
        args: [
          contracts.projects.address,
          temporaryOwner.address,
          constants.GovernanceProjectId,
          randomBytesFn()
        ]
      });
      return { temporaryOwner };
    }
  },
  {
    description: "The owner should have changed",
    fn: ({
      contracts,
      checkFn,
      randomSignerFn,
      constants,
      local: { temporaryOwner }
    }) =>
      checkFn({
        caller: randomSignerFn(),
        contract: contracts.projects,
        fn: "ownerOf",
        args: [constants.GovernanceProjectId],
        expect: temporaryOwner.address
      })
  },
  {
    description: "Transfer the project back",
    fn: ({ executeFn, contracts, constants, local: { temporaryOwner } }) =>
      executeFn({
        caller: temporaryOwner,
        contract: contracts.projects,
        fn: "transferFrom",
        args: [
          temporaryOwner.address,
          constants.ProjectOwner.address,
          constants.GovernanceProjectId
        ]
      })
  },
  {
    description: "The owner should be the original owner",
    fn: ({ contracts, checkFn, randomSignerFn, constants }) =>
      checkFn({
        caller: randomSignerFn(),
        contract: contracts.projects,
        fn: "ownerOf",
        args: [constants.GovernanceProjectId],
        expect: constants.ProjectOwner.address
      })
  },
  {
    description: "Set the old governance back",
    fn: ({ executeFn, contracts, deployer }) => {
      executeFn({
        caller: deployer,
        contract: contracts.governance,
        fn: "acceptGovernance",
        args: [contracts.terminalV1.address]
      });
    }
  }
];
