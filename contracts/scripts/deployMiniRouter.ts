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
  
  // Bsc Mainnet
  // const router_ = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
  
  // Ethereum Mainnet
  // Ropsten, Rinkeby
  // const router_ = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
  
  // Bsc Testnet
  const empire_ = "0xC369B72872e2ba9ff2e29a020B2801EE0e49452c";
  const router_ = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3";
  const weth_ = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
  const busd_ = "0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7";

  const MiniRouter = await ethers.getContractFactory("MiniRouter");
  const miniRouter = await MiniRouter.deploy(empire_, router_, weth_, busd_);

  await miniRouter.deployed();

  console.log("MiniRouter deployed to:", miniRouter.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
