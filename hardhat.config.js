/** @type import('hardhat/config').HardhatUserConfig */

const { GasData } = require('hardhat-gas-reporter/dist/lib/gasData');
require("dotenv").config();
// eslint-disable-next-line node/no-extraneous-require

// require("@nomiclabs/hardhat-ethers");
// require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-gas-reporter");
require('hardhat-deploy');
require("solidity-coverage");
require("@nomicfoundation/hardhat-ethers");
// require("@nomiclabs/hardhat-etherscan");
require("@nomicfoundation/hardhat-verify");

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.27",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true
        },
      }     
    ],
  },
  // forking: {
  //   url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
  //   allowUnlimitedContractSize: true,   
  // },
  networks: {
    // defaultNetwork: "local",
    hardhat: {
      gas: "auto", 
      gasPrice: "auto",
      timeout: 20000,
      chainId: 1337,
      allowUnlimitedContractSize: true,
      accounts: {
        mnemonic: "grid test test test test test test test test test test junk",
      }
      // forking: {
      //   url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}` || "",
      //   allowUnlimitedContractSize: true,   
      // },
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      gas: "auto", 
      gasPrice: "auto",
      allowUnlimitedContractSize: true,
      accounts: {
        mnemonic: "grid test test test test test test test test test test junk",
      }
    },
    // mainnet: {
    //   url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [`0x${YOUR_PRIVATE_KEY}`], // add your mainnet private key here if you want to deploy or run scripts on mainnet
    // },
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      // url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [`0x${process.env.EVM_PRIVATE_KEY}`], // add your sepolia private key here if you want to deploy or run scripts on sepolia
      chainId: 11155111,  
      // gasPrice: 80000000000,
      gasMultiplier: 1.2,
      timeout: 60000,  // Increase timeout to 60 seconds
      gas: "auto",
      allowUnlimitedContractSize: true
    },

    amoy: { 
      url: `https://polygon-amoy.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`0x${process.env.EVM_PRIVATE_KEY}`],
      chainId: 80002,
      gasPrice: 40000000000,
      gas: "auto",
      allowUnlimitedContractSize: true
    }
    // ... add other networks as needed
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY 
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
    // apiKey: process.env.BSCSCAN_API_KEY,
    // apiKey: process.env.SHOWTRACE_API_KEY
  },
};
