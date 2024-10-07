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

        // clean nonce issue and stuck txns
        const nonce = await ethers.provider.getTransactionCount(deployer.address);
        console.log(`Current nonce: ${nonce}`);
        // await clearPendingTransactions(deployer, nonce, nonce + 2); 


        // Get the network name and chainId
        const network = hre.network.name.toUpperCase();
        const chainId = await hre.ethers.provider.getNetwork().then(net => net.chainId);

        // Read Permit2 address from environment variable
        const permit2 = process.env[`PERMIT2`];

        if (!permit2) {
            console.error(`Permit2 address not found. Please set PERMIT2 in your .env file.`);
            process.exit(1);
        }

        console.log(`Using Permit2 address for ${network}:`, permit2);

        // Deploy PaymentCore library - Removed, since its now inlined in the GridPaymentGateway bytecode.
        // const _PaymentCore = await ethers.getContractFactory("PaymentCore");

        // const estimatedGas = await ethers.provider.estimateGas(_PaymentCore.getDeployTransaction());
        // console.log(`PaymentCore deployment estimated gas limit: ${estimatedGas.toString()}`);

        // // Fetch current network gas fees
        // const feeData = await ethers.provider.getFeeData();
        // console.log("Current Gas Fee Data:", feeData);

        // const paymentCoreTx = await PaymentCore.deploy();
        // // {
        // //     gasLimit: ethers.toBigInt('2000000'),  // Set a higher gas limit
        // //     maxFeePerGas: feeData.maxFeePerGas,
        // //     maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
        // // }
        // console.log("PaymentCore deployment transaction hash:", paymentCoreTx.deploymentTransaction().hash);
        // await paymentCoreTx.waitForDeployment();
        // const paymentCore = await paymentCoreTx.getAddress();
        // console.log("PaymentCore library deployed to: ", paymentCore);
        // const paymentCore = "0x3cd46De74859CD566Ae206b27D899262137DDd99";
        
        const GridPaymentGateway = await ethers.getContractFactory("GridPaymentGateway");
        // Deployment GridPaymentGateway implementation contract separately
        // let GridPaymentGatewayImplementation;
        // let GridPaymentGatewayAddress;
        // try {
        //     // Deploy the GridPaymentGateway implementation
        //     GridPaymentGatewayImplementation = await GridPaymentGateway.deploy();
        //     console.log("GridPaymentGateway deployment transaction hash:", GridPaymentGatewayImplementation.deploymentTransaction().hash);
        //     await GridPaymentGatewayImplementation.waitForDeployment();
        //     GridPaymentGatewayAddress = await GridPaymentGatewayImplementation.getAddress();
        //     console.log("GridPaymentGateway Implementation deployed to: ", GridPaymentGatewayAddress);
        //     // OLD ADDRESS = 0x1eB6958774e873AC152fe5e01681A48B343E143E
        // } catch (error) {
        //     console.error("Error deploying GridPaymentGateway:", error);
        //     throw error;
        // }

        const defaultConfig = {
            relayer_address: "0x51D7f3dbAbc4c78D8412A677b2B0520C82f512e4",
            fee: 10, // basis point = 0.1%
            treasury: "0x51D7f3dbAbc4c78D8412A677b2B0520C82f512e4" // ethers.constants.AddressZero
        };

        // Deploy UUPS Proxy with CREATE2 and set implementation to GridPaymentGateway
        // Prepare GridOperatorProxy deployment
        // const ProxyFactory = await ethers.getContractFactory("ERC1967Proxy");
        // const initializeData = GridPaymentGateway.interface.encodeFunctionData("initialize", [permit2, defaultConfig]);
        // const proxyBytecode = ProxyFactory.bytecode + ProxyFactory.interface.encodeDeploy([GridPaymentGatewayAddress, initializeData]).slice(2);
        // const proxyInitCodeHash = keccak256(proxyBytecode);

        // const salt = ethers.utils.formatBytes32String(process.env[`CREATE2_SALT`]);

        // // This is the keccak256 hash of the contract bytecode
        // const GPGInitCodeHash = keccak256(GridPaymentGateway.bytecode);
        // // Precompute the deterministic address
        // // Parameters:
        // //   1. factory.address: Address of the OpenZeppelin factory contract (not the deployer's address)
        // //   2. salt: A unique value to ensure deployment uniqueness
        // //   3. initCodeHash: Hash of the contract bytecode
        // // The resulting address will be the same across all networks if these parameters are the same
        // const precomputedProxyAddress = getCreate2Address(
        //     deployer.address,
        //     salt,
        //     proxyInitCodeHash // use proxy init code hash instead of GPGInitCodeHash
        // );

        // console.log("Precomputed CREATE2 GridOperatorProxy address:", precomputedProxyAddress);

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

       // Get the implementation address
       const GridPaymentGatewayAddress = await upgrades.erc1967.getImplementationAddress(GridOperatorProxy);
       console.log("GridPaymentGateway deployed to address:", GridPaymentGatewayAddress);

        // // CREATE2: Verify the deployed address matches the precomputed address
        // if (GridOperatorProxy.toLowerCase() !== precomputedProxyAddress.toLowerCase()) {
        //     console.error("WARNING: Deployed address does not match precomputed address!");
        // } else {
        //     console.log("Deployed address matches precomputed address.");
        // }

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
                    source: "UNISWAP ENTRYPOINT ADDRESS",
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