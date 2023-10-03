/** @type import('hardhat/config').HardhatUserConfig */

require("dotenv").config();
// eslint-disable-next-line node/no-extraneous-require

require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
// require("@nomiclabs/hardhat-etherscan");
// require("@nomicfoundation/hardhat-verify");
require("hardhat-gas-reporter");
require("solidity-coverage");

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 20,
          },
        },
      }
    ],
  },

  networks: {
    // defaultNetwork: "local",
    hardhat: {
      gas: "auto", 
      gasPrice: "auto",
      timeout: 10000,
      chainId: 1337,
      // allowUnlimitedContractSize: true,
      accounts: {
        mnemonic: process.env.MNEMONIC
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
        mnemonic: process.env.MNEMONIC
      }
    },
    // mainnet: {
    //   url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
    //   accounts: [`0x${YOUR_PRIVATE_KEY}`], // add your mainnet private key here if you want to deploy or run scripts on mainnet
    // },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY_SEPOLIA}`,
      accounts: [`0x${process.env.EVM_PRIVATE_KEY}`], // add your sepolia private key here if you want to deploy or run scripts on sepolia
      // chainId: 100,
      gasPrice: 30000000000,
      gas: "auto"
    },

    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY_MUMBAI}`,
      accounts: [`0x${process.env.EVM_PRIVATE_KEY}`], // add your mumbai private key here if you want to deploy or run scripts on mumbai
      chainId: 80001,
      gasPrice: 20000000000,
      gas: "auto"
    }
    // ... add other networks as needed
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
    // apiKey: process.env.BSCSCAN_API_KEY,
    // apiKey: process.env.SHOWTRACE_API_KEY
  },
};
