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
  const _marketingWallet = "0x885Aec56Bd62ccafc8e55CF19997aCddaa2fe73b";
  const _teamWallet = "0x2b538414570e2134B6A9fC6d504c3b38cA016Cf3";

  const EmpireToken = await ethers.getContractFactory("EmpireToken");
  const empireToken = await EmpireToken.deploy(_marketingWallet, _teamWallet);

  await empireToken.deployed();

  console.log("EmpireToken deployed to:", empireToken.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
