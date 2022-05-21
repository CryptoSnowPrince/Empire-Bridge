// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const _validator = "0x256C9FbE9093E7b9E3C4584aDBC3066D8c6216da";
  const _treasury = "0x7F77451e9c89058556674C5b82Bd5A4fab601AFC";

  const Bridge = await ethers.getContractFactory("Bridge");
  const bridge = await Bridge.deploy(_validator, _treasury);

  await bridge.deployed();

  console.log("Bridge deployed to:", bridge.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
