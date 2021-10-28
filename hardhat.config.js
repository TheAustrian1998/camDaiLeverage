require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");

const { rpc, apiKey } = require("./secrets.json");

module.exports = {
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      forking: {
        url: rpc,
        timeout: 2000000
      }
    },
    polygon: {
      url: rpc,
      timeout: 2000000
    }
  },
  etherscan: {
    apiKey: apiKey
  },
  gasReporter: {
    excludeContracts: ["ERC20.sol"]
  }
};