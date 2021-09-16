const chalk = require("chalk");

const juice = require("../scripts/utils");

/**
 * Deploys the TokenRepresentationProxy contract.
 *
 * Example usage:
 * npx hardhat deployTokenRepresentationProxy \
 *   --ticketbooth 0xee2eBCcB7CDb34a8A822b589F9E8427C24351bfc \
 *   --projectid 0x01 \
 *   --name "JBX Proxy" \
 *   --ticker JBXPROXY \
 *   --network rinkeby
 */
task("deployBanny", "Deploys the Banny contract").setAction(
  async (taskArgs) => {
    const contract = "Banny";
    console.log(
      `Deploying `,
      chalk.magenta(contract),
      `with the following params: `
    );
    await juice.deploy(contract, []);
    console.log(`Successfully deployed `, chalk.magenta(contract));
  }
);
