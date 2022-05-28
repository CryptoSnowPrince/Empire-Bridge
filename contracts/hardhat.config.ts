import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
    ]
  },
  networks: {
    ropsten: {
      url: process.env.ROPSTEN_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    rinkeby: {
      url: process.env.RINKEBY_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    bsc: {
      url: process.env.BSC_URL || "",
      accounts:
        process.env.BSC_GOOSEBUMPS_PRIVATE_KEY !== undefined ? [process.env.BSC_GOOSEBUMPS_PRIVATE_KEY] : [],
    },
    bsctestnet: {
      url: process.env.BSCTESTNET_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    tethermoon: {
      url: process.env.TETHERMOON_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    polygon: {
      url: process.env.POLYGON_URL || "",
      accounts:
        process.env.POLYGON_GOOSEBUMPS_PRIVATE_KEY !== undefined ? [process.env.POLYGON_GOOSEBUMPS_PRIVATE_KEY] : [],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
        mainnet: process.env.ETHERSCAN_API_KEY,
        ropsten: process.env.ETHERSCAN_API_KEY,
        rinkeby: process.env.ETHERSCAN_API_KEY,
        goerli: process.env.ETHERSCAN_API_KEY,
        kovan: process.env.ETHERSCAN_API_KEY,
        // binance smart chain
        bsc: process.env.BSCSCAN_API_KEY,
        bscTestnet: process.env.BSCSCAN_API_KEY,
        // huobi eco chain
        heco: "YOUR_HECOINFO_API_KEY",
        hecoTestnet: "YOUR_HECOINFO_API_KEY",
        // fantom mainnet
        opera: "YOUR_FTMSCAN_API_KEY",
        ftmTestnet: "YOUR_FTMSCAN_API_KEY",
        // optimism
        optimisticEthereum: "YOUR_OPTIMISTIC_ETHERSCAN_API_KEY",
        optimisticKovan: "YOUR_OPTIMISTIC_ETHERSCAN_API_KEY",
        // polygon
        polygon: process.env.POLYGON_API_KEY,
        polygonMumbai: process.env.POLYGON_API_KEY,
        // arbitrum
        arbitrumOne: "YOUR_ARBISCAN_API_KEY",
        arbitrumTestnet: "YOUR_ARBISCAN_API_KEY",
        // avalanche
        avalanche: "YOUR_SNOWTRACE_API_KEY",
        avalancheFujiTestnet: "YOUR_SNOWTRACE_API_KEY",
        // moonbeam
        moonbeam: "YOUR_MOONBEAM_MOONSCAN_API_KEY",
        moonriver: "YOUR_MOONRIVER_MOONSCAN_API_KEY",
        moonbaseAlpha: "YOUR_MOONBEAM_MOONSCAN_API_KEY",
        // harmony
        harmony: "YOUR_HARMONY_API_KEY",
        harmonyTest: "YOUR_HARMONY_API_KEY",
        // xdai and sokol don't need an API key, but you still need
        // to specify one; any string placeholder will work
        xdai: "api-key",
        sokol: "api-key",
        aurora: "api-key",
        auroraTestnet: "api-key",
    }
  }
};

export default config;
