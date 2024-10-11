// deploy_permit2.js

const hre = require("hardhat");
const { ethers } = require("hardhat");

// For more information about the deployment with Foundry and Permit2 integration:
// https://github.com/Uniswap/permit2/tree/cc56ad0f3439c502c246fc5cfcc3db92bb8b7219

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying Permit2 with the account:", deployer.address);

  // Deploy Permit2
  const Permit2 = await ethers.getContractFactory("Permit2");
  const permit2 = await Permit2.deploy();
  await permit2.waitForDeployment();
  const permit2addr = await permit2.getAddress();
  console.log("Permit2 deployed to:", permit2addr);

  // Save deployment address
  const deploymentInfo = {
    Permit2: permit2addr,
  };

//   const network = hre.network.name;
//   const filePath = path.join(__dirname, `../deployments/${network}_permit2.json`);
//   fs.writeFileSync(filePath, JSON.stringify(deploymentInfo, null, 2));
  console.log("Permit2 deployment address", deploymentInfo);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });