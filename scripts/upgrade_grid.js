// upgrade_grid.js

require('dotenv').config();
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    try {
        const [deployer] = await ethers.getSigners();
        console.log("Upgrading grid contracts with the account:", deployer.address);

        const network = hre.network.name.toUpperCase();
        const chainId = await hre.ethers.provider.getNetwork().then(net => net.chainId);

        // Read the current deployment info
        const protocolFilePath = path.join(__dirname, `${network.toLowerCase()}_gridprotocol.json`);
        let deploymentInfo = JSON.parse(fs.readFileSync(protocolFilePath, 'utf8'));

        const GridOperatorProxy = deploymentInfo.contracts.GridPaymentGateway.proxy;
        console.log("Current GridPaymentGateway Proxy address:", GridOperatorProxy);

        // Get the new implementation contract factory
        const GridPaymentGatewayV2 = await ethers.getContractFactory("GridPaymentGateway");

        console.log("Preparing upgrade...");

        // Validate the upgrade
        console.log("Validating upgrade...");
        await upgrades.validateUpgrade(GridOperatorProxy, GridPaymentGatewayV2);
        console.log("Upgrade validated successfully");

        // Perform the upgrade
        console.log("Upgrading GridPaymentGateway...");
        const upgradedProxy = await upgrades.upgradeProxy(GridOperatorProxy, GridPaymentGatewayV2, {
            // call: {fn: 'reinitialize'}, // Include if there's a new initializer function named 'reinitialize'
        });

        console.log("Upgrade transaction hash:", upgradedProxy.deployTransaction().hash);
        await upgradedProxy.waitForDeployment();
        console.log("GridPaymentGateway upgraded successfully");

        // Get the new implementation address
        const newGridPaymentGatewayImpl = await upgrades.erc1967.getImplementationAddress(GridOperatorProxy);
        console.log("New implementation address:", newGridPaymentGatewayImpl);

        // Get the new version
        const upgradedContract = await ethers.getContractAt("GridPaymentGateway", GridOperatorProxy);
        const newVersion = await upgradedContract.version();
        console.log("New GridPaymentGateway version:", newVersion);

        // Prepare new deployment info
        const newUpgradeInfo = {
            timestamp: new Date().toISOString(),
            deployer: deployer.address,
            implementation: newGridPaymentGatewayImpl,
            version: newVersion,
            previousImplementation: deploymentInfo.contracts.GridPaymentGateway.implementation
        };
        
        // Update deployment history
        if (!deploymentInfo.upgradeHistory) {
            deploymentInfo.upgradeHistory = [];
        }
        deploymentInfo.upgradeHistory.push(newUpgradeInfo);
        
        // Update current deployment info
        deploymentInfo.contracts.GridPaymentGateway.implementation = newGridPaymentGatewayImpl;
        deploymentInfo.contracts.GridPaymentGateway.version = newVersion;

        // Save updated deployment info
        fs.writeFileSync(protocolFilePath, JSON.stringify(deploymentInfo, customReplacer, 2));
        console.log(`Updated deployment info saved to ${protocolFilePath}`);

        console.log("Upgrade completed successfully!");

    } catch (error) {
        console.error("Upgrade failed:", error);
        process.exit(1);
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