// deploy_grid.js

require('dotenv').config();
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");
const { getCreate2Address } = require('@ethersproject/address');
const { keccak256 } = require('@ethersproject/keccak256');

async function main() {
    try {
        const [deployer] = await ethers.getSigners();

        console.log("Deploying contracts with the account:", deployer.address);

        // Get the network name and chainId
        const network = hre.network.name.toUpperCase();
        const chainId = await hre.ethers.provider.getNetwork().then(net => net.chainId);

        // Read Permit2 address from environment variable or deploy if not deployed yet
        const permit2 = process.env[`PERMIT2`];

        if (!permit2) {
            console.error(`Permit2 address not found. Please set PERMIT2 in your .env file.`);
            process.exit(1);
        }

        console.log(`Using Permit2 address for ${network}:`, permit2);

        const GridPaymentGateway = await ethers.getContractFactory("GridPaymentGateway");

        const defaultConfig = {
            relayer_address: "0xRELAY_ADDRESS",
            fee: 10, // basis point = 0.1%
            treasury: "0xTREASURY_ADDRESS" // ethers.constants.AddressZero
        };

        let GridOperatorProxy;
        try{
            // Deploy GridOperatorProxy UUPS Proxy
            const GridOperatorProxyTx = await upgrades.deployProxy(
                GridPaymentGateway,
                [permit2, defaultConfig],
                {
                    initializer: "initialize",
                    kind: "uups",
                    pollingInterval: 10000,  // Check every 10 seconds
                    timeout: 180000  // Wait up to 2mins
                    // salt: salt,
                    // deployer: deployer, // Specify the deployer explicitly
                }
            );

            console.log("GridOperatorProxy deployment transaction hash:", GridOperatorProxyTx.deploymentTransaction().hash);
            GridOperatorProxy = await GridOperatorProxyTx.getAddress();
            console.log("GridOperatorProxy (with UUPS) deployed to:", GridOperatorProxy);

            // Add a delay before verification
            await new Promise(resolve => setTimeout(resolve, 10000));

        } catch (error) {
            console.error("Error deploying GridOperatorProxy:", error);
            throw error;
        }

        console.log("Validating implementation...");
        await upgrades.validateImplementation(GridPaymentGateway);
        console.log("Implementation validated successfully");

        await new Promise(resolve => setTimeout(resolve, 7000)); // 7s

       // Get the implementation address
       const GridPaymentGatewayAddress = await upgrades.erc1967.getImplementationAddress(GridOperatorProxy);
       console.log("GridPaymentGateway deployed to address:", GridPaymentGatewayAddress);

        // Get GridPaymentGateway version
        let GridPaymentGatewayVersion;
        try {
            const GridOperatorProxyInstance = await ethers.getContractAt("GridPaymentGateway", GridOperatorProxy);
            GridPaymentGatewayVersion = await GridOperatorProxyInstance.version();
            console.log("GridPaymentGateway version:", GridPaymentGatewayVersion);
        } catch (error) {
            console.error("Error getting GridPaymentGateway version:", error);
            GridPaymentGatewayVersion = "Unknown";
        }

        // Get gas prices
        const _gasPrice = await ethers.provider.getFeeData();

        // Save deployment addresses
        const deploymentInfo = {
            network: {
                name: network,
                chainId: chainId,
            },
            deployer: deployer.address,
            contracts: {
                Permit2: {
                    address: permit2,
                    source: "UNISWAP_ENTRYPOINT",
                },
                GridPaymentGateway: {
                    proxy: GridOperatorProxy,
                    implementation: GridPaymentGatewayAddress,
                    version: GridPaymentGatewayVersion,
                },
            },
            deploymentDetails: {
                timestamp: new Date().toISOString(),
                defaultConfig: defaultConfig,
            },
        };

        console.log("Protocol deployment info:");
        console.dir(deploymentInfo, { depth: null, colors: true });


    // Save deployment addresses and additional info
    //   const deploymentInfo = {
    //     network: {
    //       name: network,
    //       chainId: chainId,
    //     },
    //     deployer: deployer.address,
    //     contracts: {
    //       Permit2: {
    //         address: permit2,
    //         source: "UNISWAP ENTRYPOINT ADDRESS",
    //       },
    //       PaymentCore: {
    //         address: paymentCore.address,
    //         version: paymentCoreVersion,
    //       },
    //       GridOperatorProxy: {
    //         address: GridOperatorProxy.address,
    //         name: "GRID_PAYMENT_GATEWAY",
    //         implementation: implementationAddress,
    //         version: GridPaymentGatewayVersion,
    //       },
    //     },
    //     deploymentDetails: {
    //       timestamp: new Date().toISOString(),
    //       gasPrice: gasPrice.toString(),
    //       defaultConfig: defaultConfig,
    //       salt: salt,
    //     },
    //   };
    
        const protocolFilePath = path.join(__dirname, `${network.toLowerCase()}_gridprotocol.json`);
        fs.writeFileSync(protocolFilePath, JSON.stringify(deploymentInfo, customReplacer, 2));
        console.log(`Protocol deployment info saved to ${protocolFilePath}`);

    } catch (error) {
        console.error("Deployment failed:", error);
        process.exit(1);
    }
}

async function clearPendingTransactions(signer, startNonce, endNonce) {
    const feeData = await ethers.provider.getFeeData();
    const currentGasPrice = feeData.gasPrice;
    const higherGasPrice = currentGasPrice * 120n / 100n; // 20% higher

    for (let i = startNonce; i <= endNonce; i++) {
        const tx = await signer.sendTransaction({
            to: signer.address,
            value: 0n,
            nonce: i,
            gasPrice: higherGasPrice
        });
        console.log(`Clearing nonce ${i}, tx hash: ${tx.hash}`);
        await tx.wait();
    }
}

// Custom replacer function to handle BigInt serialization
function customReplacer(key, value) {
    if (typeof value === 'bigint') {
        return value.toString();
    }
    return value;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });