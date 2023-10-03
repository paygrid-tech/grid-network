const { expect } = require("chai");
const { ethers, upgrades, utils, waffle} = require("hardhat");
// const { waffleChai } = require('@ethereum-waffle/chai');
// chai.use(waffleChai);


const USDC_DECIMALS = 6;
// const USDC_ADDRESS = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8"; // USDC Sepolia address
// const USDC_ADDRESS = "0x52D800ca262522580CeBAD275395ca6e7598C014"; // USDC Mumbai address


function toUSDCUnits(value) {
    return BigInt(Math.round(value * 10 ** USDC_DECIMALS).toString());
}

function toHumanReadable(valueBigInt) {
    // Convert the BigInt value back to a float
    const floatValue = Number(valueBigInt) / (10 ** USDC_DECIMALS);
    
    // Format the float to a currency string
    return floatValue.toFixed(6); // Show up to two decimal places for cents
}


describe("PaymentCore with USDC", function () {
    let PaymentCore, paymentCore, paymentCoreImpl, paymentCoreProxyAddress, USDC, owner, admin, user1, user2, treasuryWallet;
    let mockUSDC;

    beforeEach(async function () {
        // Fetch accounts
        [owner, admin, user1, user2, treasuryWallet] = await ethers.getSigners();

        // Get a handle on the USDC token deployed on the testnet
        // USDC = await ethers.getContractAt("IERC20", USDC_ADDRESS);

        mockUSDC = await ethers.getContractFactory("MockUSDC");
        mockUSDC = await mockUSDC.deploy();

        USDC_ADDRESS = await mockUSDC.getAddress();
        
        // Mint some USDC to `user1` for testing purposes.        
        await mockUSDC.mint(user1.address, toUSDCUnits(10000));

        // Deploy the PaymentCore contract
        PaymentCore = await ethers.getContractFactory("PaymentCore");
        paymentCoreImpl = await PaymentCore.deploy();

        paymentCore = await upgrades.deployProxy(PaymentCore, [treasuryWallet.address], { initializer: 'initialize'});

        paymentCoreProxyAddress = await paymentCore.getAddress();
        
        // Setup an admin
        await paymentCore.grantAdmin(admin.address);

        /* Add support for the mockUSDC */
        if (!(await paymentCore.isTokenSupported(USDC_ADDRESS))){
            await paymentCore.connect(admin).addSupportedToken(USDC_ADDRESS, "USDC");
        }
        
    });

    describe("Payment processing", function () {
            // Mint some USDC to `user1` for testing purposes.
            // Note: This step is for illustration. You can't mint USDC like this on a real testnet.
            // You'd typically acquire USDC from a testnet faucet or by testing your script against a mock USDC contract.
            beforeEach(async function() {
                // Reset the state by ensuring user1 has enough USDC and user2 and treasuryWallet have zero
                await mockUSDC.mint(user1.address, toUSDCUnits(10000));
                // await mockUSDC.connect(user1).transfer(USDC_ADDRESS, await mockUSDC.balanceOf(user1.address));
                // await mockUSDC.connect(user2).transfer(USDC_ADDRESS, await mockUSDC.balanceOf(user2.address));
                // await mockUSDC.connect(treasuryWallet).transfer(USDC_ADDRESS, await mockUSDC.balanceOf(treasuryWallet.address));                
            });
    
            const testPayment = async (amountInUSDC) => {
                const paymentAmount = toUSDCUnits(amountInUSDC);
                const fee = BigInt(await paymentCore.calculateProtocolFees(paymentAmount));
                const paymentAfterFee = paymentAmount - fee;

                console.log("Payment Amount:", toHumanReadable(paymentAmount).toString(), "USDC");
                console.log("Fee:", toHumanReadable(fee).toString(), "USDC");
                console.log("Payment After Fee:", toHumanReadable(paymentAfterFee).toString(), "USDC");
    
                await mockUSDC.connect(user1).approve(paymentCoreProxyAddress, paymentAmount);
                await paymentCore.connect(admin).processPayment(user1.address, user2.address, USDC_ADDRESS, paymentAmount);

                console.log("User1 (Customer) balance: ", toHumanReadable((await mockUSDC.balanceOf(user1.address))), "USDC");
                console.log("User2 (Merchant) balance: ", toHumanReadable((await mockUSDC.balanceOf(user2.address))), "USDC");
                console.log("treasuryWallet balance : ", toHumanReadable((await mockUSDC.balanceOf(treasuryWallet.address))), "USDC");
                
                expect(BigInt(await mockUSDC.balanceOf(user2.address))).to.equal(paymentAfterFee);
                expect(BigInt(await mockUSDC.balanceOf(treasuryWallet.address))).to.equal(fee);
            }
    
            it("should process whole number payment correctly", async function () {
                await testPayment(10); // 10 USDC
            });
    
            it("should process floating payment correctly", async function () {
                // await testPayment(10.25);
                await testPayment(5.99);
                // await testPayment(8.5);
            });
    });

    describe("Admin functions", function () {

        beforeEach(async function() {
            /* clean up for future test cases */
            await paymentCore.connect(admin).removeSupportedToken(USDC_ADDRESS);
        });
       
        it("should allow admins to add supported tokens", async function () {
            await paymentCore.connect(admin).addSupportedToken(USDC_ADDRESS, "USDC");
            const tokenInfo = await paymentCore.supportedTokens(USDC_ADDRESS);
            expect(tokenInfo.isSupported).to.equal(true);
            expect(tokenInfo.symbol).to.equal("USDC");
        });

        it("should allow admins to remove supported tokens", async function () {
            await paymentCore.connect(admin).addSupportedToken(USDC_ADDRESS, "USDC");
            await paymentCore.connect(admin).removeSupportedToken(USDC_ADDRESS);
            const tokenInfo = await paymentCore.supportedTokens(USDC_ADDRESS);
            expect(tokenInfo.isSupported).to.equal(false);
        });

        it("should prevent non-admins from adding supported tokens", async function () {
            let errorThrown = false;
            try {
                await paymentCore.connect(user1).addSupportedToken(USDC_ADDRESS, "USDC");
            } catch (error) {
                errorThrown = true;
                expect(error.message).to.include("Access denied: Caller is not a protocol operator");
            }
            expect(errorThrown, "Expected an error to be thrown").to.be.true;
        });
        
        it("should prevent non-admins from removing supported tokens", async function () {
            let errorThrown = false;
            try {
                await paymentCore.connect(user1).removeSupportedToken(USDC_ADDRESS);
            } catch (error) {
                errorThrown = true;
                expect(error.message).to.include("Access denied: Caller is not a protocol operator");
            }
            expect(errorThrown, "Expected an error to be thrown").to.be.true;
        });
        
    });
    // ... Continue with more tests
});
