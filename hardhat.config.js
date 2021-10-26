require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");

let { rpc } = require("./secrets.json");

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
        url: "http://localhost:8545",
        timeout: 2000000
      }
    },
    localhost: {
      url: "http://localhost:8545",
      timeout: 2000000000
    },
    polygon: {
      url: rpc
    }
  },
  gasReporter: {
    excludeContracts: ["ERC20.sol"]
  }
};