const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PaymentCore", function() {
    let PaymentCore, MockToken, paymentCore, mockToken, owner, addr1, addr2, treasury;

    beforeEach(async function() {
        [owner, addr1, addr2, treasury] = await ethers.getSigners();

        MockToken = await ethers.getContractFactory("MockToken");
        mockToken = await MockToken.deploy();
        await mockToken.deployed();
        
        PaymentCore = await ethers.getContractFactory("PaymentCore");
        paymentCore = await PaymentCore.deploy(treasury.address);
        await paymentCore.deployed();
    });

    describe("Deployment", function() {
        it("Should set correct treasury wallet on deploy", async function() {
            expect(await PaymentCore.getTreasuryWallet()).to.equal(treasury.address);
        });

        it("Should set protocol fee to 1% on deploy", async function() {
            expect(await paymentCore.getProtocolFee()).to.equal(1);
        });
    });

    describe("Admin Functions", function() {
        it("Should allow adding supported tokens", async function() {
            await paymentCore.connect(owner).addSupportedToken(mockToken.address, "MOCK");
            const tokenInfo = await paymentCore.supportedTokens(mockToken.address);
            expect(tokenInfo.isSupported).to.be.true;
            expect(tokenInfo.symbol).to.equal("MOCK");
        });

        it("Should allow removing supported tokens", async function() {
            await paymentCore.connect(owner).addSupportedToken(mockToken.address, "MOCK");
            await paymentCore.connect(owner).removeSupportedToken(mockToken.address);
            const tokenInfo = await paymentCore.supportedTokens(mockToken.address);
            expect(tokenInfo.isSupported).to.be.false;
        });

        it("Should allow changing protocol fee", async function() {
            await paymentCore.connect(owner).setProtocolFee(2);
            expect(await paymentCore.getProtocolFee()).to.equal(2);
        });

        it("Should allow changing treasury wallet", async function() {
            await paymentCore.connect(owner).setTreasuryWallet(addr1.address);
            expect(await paymentCore.getTreasuryWallet()).to.equal(addr1.address);
        });

        it("Should grant and revoke admin role", async function() {
            await paymentCore.connect(owner).grantAdmin(addr1.address);
            expect(await paymentCore.hasRole(await paymentCore.PG_ADMIN_ROLE(), addr1.address)).to.be.true;
            
            await paymentCore.connect(owner).revokeAdmin(addr1.address);
            expect(await paymentCore.hasRole(await paymentCore.PG_ADMIN_ROLE(), addr1.address)).to.be.false;
        });
    });

    describe("Payment Processing", function() {
        beforeEach(async function() {
            await paymentCore.connect(owner).addSupportedToken(mockToken.address, "MOCK");
            await mockToken.mint(owner.address, ethers.utils.parseEther("1000")); // Assuming mint function in MockToken
            await mockToken.approve(paymentCore.address, ethers.utils.parseEther("1000"));
        });

        it("Should process payments correctly with fee deduction", async function() {
            const initialBalance = await mockToken.balanceOf(owner.address);
            const paymentAmount = ethers.utils.parseEther("100");
            const fee = paymentAmount / 100; // 1%

            await paymentCore.connect(owner).processPayment(owner.address, addr1.address, mockToken.address, paymentAmount);
            
            const finalBalance = await mockToken.balanceOf(owner.address);
            const recipientBalance = await mockToken.balanceOf(addr1.address);
            const treasuryBalance = await mockToken.balanceOf(treasury.address);

            expect(finalBalance).to.equal(initialBalance.sub(paymentAmount));
            expect(recipientBalance).to.equal(paymentAmount.sub(fee));
            expect(treasuryBalance).to.equal(fee);
        });
    });
});

