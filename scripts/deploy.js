const { ethers, upgrades } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contract with the account:", deployer.address);
    console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

    const PaymentCore = await ethers.getContractFactory("PaymentCore");
    console.log("Deploying Implementation...");
    
    // Deploy just the implementation without proxy
    const paymentCoreImpl = await PaymentCore.deploy();
    const paymentCoreImplAddress = await paymentCoreImpl.getAddress();
    console.log("PaymentCore Implementation deployed to:", paymentCoreImplAddress);
   
    // // Deploy the proxy and simultaneously call the initializer with the treasuryWallet address
    console.log("Deploying and initializing proxy...");
    let paymentCoreProxy;
    try {
        paymentCoreProxy = await upgrades.deployProxy(PaymentCore, ["0x4768d9c51b152153d29efe003aebf19f88152ce9"], 
            { 
            initializer: 'initialize', 
            gasLimit: 5000000, 
            pollingInterval: 15000,  // Check every 15 seconds
            timeout: 600000  // Wait up to 10 minutes
            }  
        );
        const proxyAddress = await paymentCoreProxy.getAddress();
        console.log("PaymentCore proxy deployed to:", proxyAddress);
    } catch (error) {
        console.error("Error deploying proxy:", error);
    }

    // /* ETHEREUM SEPOLIAAAAAAAAAAA  */
    // // Add a token to the supported tokens list using the proxy
    // await paymentCoreProxy.addSupportedToken("0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8", "USDC");

    // // Add a token to the supported tokens list using the proxy
    // await paymentCoreProxy.addSupportedToken("0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0", "USDT");

    //     // Add a token to the supported tokens list using the proxy
    // await paymentCoreProxy.addSupportedToken("0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357", "DAI");

    /* POLYGON MUMBAAAII  */
    // Add a token to the supported tokens list using the proxy
    await paymentCoreProxy.addSupportedToken("0xd33602Ce228aDBc90625e4FC8071aAE0CAd11Fe9", "USDC");

    // Add a token to the supported tokens list using the proxy
    await paymentCoreProxy.addSupportedToken("0x466DD1e48570FAA2E7f69B75139813e4F8EF75c2", "USDT");

        // Add a token to the supported tokens list using the proxy
    await paymentCoreProxy.addSupportedToken("0x3eA3EfA40DB89571E9d0bbF123678E90647644EE", "DAI");
    // Check if the token is supported
    result = await paymentCoreProxy.getSupportedTokens();
    console.log("Supported Tokens :", result);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


// Optional: Confirm that deployer has PG_ADMIN_ROLE
//   const PG_ADMIN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("PG_ADMIN_ROLE"));
//   const hasAdminRole = await paymentCore.hasRole(PG_ADMIN_ROLE, deployer.address);
//   console.log("Deployer has PG_ADMIN_ROLE:", hasAdminRole);
// const hasRole = await paymentCore.hasRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("PG_ADMIN_ROLE")), deployer.address);
// console.log(`Deployer has PG_ADMIN_ROLE: ${hasRole}`);
// await paymentCore.initialize(treasuryWallet.address);