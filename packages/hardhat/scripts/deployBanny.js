// Script to deploy ProxyAddressManager to mainnet.
//
// Usage:
// cd packages/hardhat
// npx hardhat run scripts/deployProxyPaymentAddressManager.js --network mainnet

/* eslint no-use-before-define: "warn" */
const chalk = require("chalk");
const publish = require("./publish");
const juice = require("./utils");

/* eslint no-use-before-define: "warn" */

const network = process.env.HARDHAT_NETWORK;

const main = async () => {
  // TODO: this kind of logic could be generalized.
  // We should be able to get a deployed address of a contract for a given network.
  if (network !== "mainnet" && network !== "rinkeby") {
    throw "⚠️  This script should only be used when deploying to mainnet or rinkeby";
  }
  const startBlock = await ethers.provider.getBlockNumber();
  console.log("Start block:", startBlock);
  console.log("Deploying:", chalk.yellow("ProxyPaymentAddressManager"), "\n");

  const banny = await juice.deploy("Banny", []);
  console.log("\n");
  console.log(
    "⚡️ Contract artifacts saved to:",
    chalk.yellow("packages/hardhat/artifacts/"),
    "\n"
  );
  const BannyFactory = await ethers.getContractFactory("Banny");

  const attachedBanny = await BannyFactory.attach(banny.address);
  // Transfer ownership of governance to the multisig.
  await attachedBanny.transferOwnership(juice.multisigAddress);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
