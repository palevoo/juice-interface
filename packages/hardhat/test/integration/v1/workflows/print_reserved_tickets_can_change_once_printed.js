/**
 Projects that have configured a reserve rate will be reserved tickets each time 
 a payment is made to it.

 These reserved tickets can be printed at any time.

 Any configured ticket mods will get sent some of the printing reserved tickets at this time.
*/

// The currency will be 0, which corresponds to ETH, preventing the need for currency price conversion.
const currency = 0;

module.exports = [
  {
    description: "Create a project",
    fn: async ({
      randomSignerFn,
      contracts,
      executeFn,
      randomBytesFn,
      randomStringFn,
      incrementProjectIdFn
    }) => {
      const expectedProjectId = incrementProjectIdFn();

      // The owner of the project that will migrate.
      const owner = randomSignerFn();

      await executeFn({
        caller: randomSignerFn(),
        contract: contracts.projects,
        fn: "create",
        args: [
          owner.address,
          randomBytesFn({
            // Make sure its unique by prepending the id.
            prepend: expectedProjectId.toString()
          }),
          randomStringFn(),
          // Set the terminalV1 to the terminal.
          contracts.terminalV1.address
        ]
      });

      return { expectedProjectId, owner };
    }
  },
  {
    description:
      "Configure the projects funding cycle with a reserved rate of 0 and duration of 0",
    fn: async ({
      constants,
      contracts,
      BigNumber,
      executeFn,
      getBalanceFn,
      randomBigNumberFn,
      randomBoolFn,
      randomSignerFn,
      incrementFundingCycleIdFn,
      local: { expectedProjectId, owner }
    }) => {
      // An account that will be used to make payments.
      const payer = randomSignerFn({ exclude: [owner.address] });

      // Burn the unused funding cycle ID id.
      incrementFundingCycleIdFn();

      const paymentValue1 = randomBigNumberFn({
        min: BigNumber.from(1),
        max: (await getBalanceFn(payer.address)).div(100)
      });

      const target = randomBigNumberFn({
        max: paymentValue1
      });

      // The preference for unstaked tickets.
      const preferUnstaked = randomBoolFn();

      // Set to 0.
      const reservedRate = BigNumber.from(0);

      // Make duration of 0.
      const duration = BigNumber.from(0);

      // Make discount rate 0.
      const discountRate = BigNumber.from(0);

      await executeFn({
        caller: owner,
        contract: contracts.terminalV1,
        fn: "configure",
        args: [
          expectedProjectId,
          {
            target,
            currency,
            duration,
            cycleLimit: randomBigNumberFn({
              max: constants.MaxCycleLimit
            }),
            discountRate,
            ballot: constants.AddressZero
          },
          {
            reservedRate,
            bondingCurveRate: randomBigNumberFn({
              max: constants.MaxPercent
            }),
            reconfigurationBondingCurveRate: randomBigNumberFn({
              max: constants.MaxPercent
            })
          },
          [],
          []
        ]
      });

      return {
        paymentValue1,
        preferUnstaked,
        reservedRate,
        payer,
        target
      };
    }
  },
  {
    description: "The owner should not have any tickets initially",
    fn: ({
      contracts,
      checkFn,
      randomSignerFn,
      local: { expectedProjectId, owner }
    }) =>
      checkFn({
        caller: randomSignerFn(),
        contract: contracts.ticketBooth,
        fn: "balanceOf",
        args: [owner.address, expectedProjectId],
        expect: 0
      })
  },
  {
    description:
      "Printing reserved before anything has been done shouldn't do anything",
    fn: ({ contracts, executeFn, local: { expectedProjectId, owner } }) =>
      executeFn({
        caller: owner,
        contract: contracts.terminalV1,
        fn: "printReservedTickets",
        args: [expectedProjectId]
      })
  },
  {
    description: "The owner should still not have any tickets",
    fn: ({
      contracts,
      checkFn,
      randomSignerFn,
      local: { expectedProjectId, owner }
    }) =>
      checkFn({
        caller: randomSignerFn(),
        contract: contracts.ticketBooth,
        fn: "balanceOf",
        args: [owner.address, expectedProjectId],
        expect: 0
      })
  },
  {
    description: "Make a payment to the project",
    fn: async ({
      contracts,
      executeFn,
      randomBoolFn,
      randomStringFn,
      randomSignerFn,
      local: { expectedProjectId, payer, paymentValue1, owner }
    }) => {
      // An account that will be distributed tickets in the second payment.
      // Simplify the test by disallowing the owner or either mod beneficiary.
      const ticketBeneficiary1 = randomSignerFn({
        exclude: [owner.address]
      });

      await executeFn({
        caller: payer,
        contract: contracts.terminalV1,
        fn: "pay",
        args: [
          expectedProjectId,
          ticketBeneficiary1.address,
          randomStringFn(),
          randomBoolFn()
        ],
        value: paymentValue1
      });

      return { ticketBeneficiary1 };
    }
  },
  {
    description: "The owner should not have printable reserved tickets",
    fn: async ({
      contracts,
      checkFn,
      randomSignerFn,
      BigNumber,
      local: { expectedProjectId, reservedRate }
    }) =>
      checkFn({
        caller: randomSignerFn(),
        contract: contracts.terminalV1,
        fn: "reservedTicketBalanceOf",
        args: [expectedProjectId, reservedRate],
        expect: BigNumber.from(0),
        // Allow some wiggle room due to possible division precision errors.
        plusMinus: {
          amount: 10000
        }
      })
  },
  {
    description: "The owner should still not have any tickets",
    fn: ({
      contracts,
      checkFn,
      randomSignerFn,
      local: { expectedProjectId, owner }
    }) =>
      checkFn({
        caller: randomSignerFn(),
        contract: contracts.ticketBooth,
        fn: "balanceOf",
        args: [owner.address, expectedProjectId],
        expect: 0
      })
  },
  {
    description:
      "Reconfigure the projects funding cycle to have a reserved rate of 1",
    fn: async ({
      constants,
      contracts,
      BigNumber,
      executeFn,
      randomBigNumberFn,
      incrementFundingCycleIdFn,
      local: {
        expectedProjectId,
        owner,
        payer,
        target,
        preconfigTicketBeneficiary
      }
    }) => {
      // Burn the unused funding cycle ID id.
      incrementFundingCycleIdFn();

      // Set to 1.
      const reservedRate = BigNumber.from(1);

      // Set to 0.
      const duration = BigNumber.from(0);

      await executeFn({
        caller: owner,
        contract: contracts.terminalV1,
        fn: "configure",
        args: [
          expectedProjectId,
          {
            target,
            currency,
            duration,
            cycleLimit: randomBigNumberFn({
              max: constants.MaxCycleLimit
            }),
            discountRate: randomBigNumberFn({ max: constants.MaxPercent }),
            ballot: constants.AddressZero
          },
          {
            reservedRate,
            bondingCurveRate: randomBigNumberFn({
              max: constants.MaxPercent
            }),
            reconfigurationBondingCurveRate: randomBigNumberFn({
              max: constants.MaxPercent
            })
          },
          [],
          []
        ]
      });

      return {
        reservedRate,
        payer,
        preconfigTicketBeneficiary
      };
    }
  },
  {
    description: "The owner should now have printable reserved tickets",
    fn: async ({
      contracts,
      checkFn,
      randomSignerFn,
      constants,
      local: { expectedProjectId, reservedRate, paymentValue1 }
    }) => {
      // The expected number of reserved tickets to expect from the first payment.
      // Since the reserved rate was 0 during the first payment, this value
      // should be found by finding the percent of the payment that would complete a full 100%
      // given the new reserved rate.
      const expectedReservedTicketAmount = paymentValue1
        .mul(constants.InitialWeightMultiplier)
        .mul(constants.MaxPercent)
        .div(constants.MaxPercent.sub(reservedRate))
        .sub(paymentValue1.mul(constants.InitialWeightMultiplier));

      await checkFn({
        caller: randomSignerFn(),
        contract: contracts.terminalV1,
        fn: "reservedTicketBalanceOf",
        args: [expectedProjectId, reservedRate],
        expect: expectedReservedTicketAmount,
        // Allow some wiggle room due to possible division precision errors.
        plusMinus: {
          amount: 10000
        }
      });
    }
  },
  {
    description: "Printing reserves",
    fn: ({ contracts, executeFn, local: { expectedProjectId, owner } }) =>
      executeFn({
        caller: owner,
        contract: contracts.terminalV1,
        fn: "printReservedTickets",
        args: [expectedProjectId]
      })
  },
  {
    description:
      "The owner should no longer have printable reserved tickets available",
    fn: async ({
      contracts,
      checkFn,
      randomSignerFn,
      local: { expectedProjectId, reservedRate }
    }) =>
      checkFn({
        caller: randomSignerFn(),
        contract: contracts.terminalV1,
        fn: "reservedTicketBalanceOf",
        args: [expectedProjectId, reservedRate],
        expect: 0
      })
  },
  {
    description:
      "Reconfigure the projects funding cycle to have a reserved rate of 100%",
    fn: async ({
      constants,
      contracts,
      BigNumber,
      executeFn,
      randomBigNumberFn,
      incrementFundingCycleIdFn,
      local: {
        expectedProjectId,
        owner,
        payer,
        target,
        preconfigTicketBeneficiary
      }
    }) => {
      // Burn the unused funding cycle ID id.
      incrementFundingCycleIdFn();

      // Set to 1.
      const reservedRate = constants.MaxPercent;

      // Set to 0.
      const duration = BigNumber.from(0);

      await executeFn({
        caller: owner,
        contract: contracts.terminalV1,
        fn: "configure",
        args: [
          expectedProjectId,
          {
            target,
            currency,
            duration,
            cycleLimit: randomBigNumberFn({
              max: constants.MaxCycleLimit
            }),
            discountRate: randomBigNumberFn({ max: constants.MaxPercent }),
            ballot: constants.AddressZero
          },
          {
            reservedRate,
            bondingCurveRate: randomBigNumberFn({
              max: constants.MaxPercent
            }),
            reconfigurationBondingCurveRate: randomBigNumberFn({
              max: constants.MaxPercent
            })
          },
          [],
          []
        ]
      });

      return {
        reservedRate,
        payer,
        preconfigTicketBeneficiary
      };
    }
  },
  {
    description:
      "The owner should still not have printable reserved tickets available",
    fn: async ({
      contracts,
      checkFn,
      randomSignerFn,
      local: { expectedProjectId, reservedRate }
    }) =>
      checkFn({
        caller: randomSignerFn(),
        contract: contracts.terminalV1,
        fn: "reservedTicketBalanceOf",
        args: [expectedProjectId, reservedRate],
        expect: 0
      })
  }
];
