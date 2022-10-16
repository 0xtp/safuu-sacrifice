const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Deploy Tokens", function () {
  before(async function() {
    this.accounts = await ethers.getSigners();
    this.owner = this.accounts[0];
    this.safuuWallet = this.accounts[1];
    this.serviceWallet = this.accounts[2];

    const USDCToken = await ethers.getContractFactory("ERC20Token");
    this.usdcToken = await USDCToken.deploy("USDC", "USDC");
    await this.usdcToken.deployed();

    const USDTToken = await ethers.getContractFactory("ERC20Token");
    this.usdtToken = await USDTToken.deploy("USDT", "USDT");
    await this.usdtToken.deployed();

    const BUSDToken = await ethers.getContractFactory("ERC20Token");
    this.busdToken = await BUSDToken.deploy("BUSD", "BUSD");
    await this.busdToken.deployed();

    const SafuuXETH = await ethers.getContractFactory("SafuuXSacrificeETH");
    this.safuuXETH = await SafuuXETH.deploy(this.safuuWallet.address, this.serviceWallet.address);
    await this.safuuXETH.deployed();
  });

  it("Should check properties match constructor", async function() {
    expect(await this.usdcToken.name()).to.equal("USDC");
    expect(await this.usdcToken.symbol()).to.equal("USDC");

    expect(await this.usdtToken.name()).to.equal("USDT");
    expect(await this.usdtToken.symbol()).to.equal("USDT");

    expect(await this.busdToken.name()).to.equal("BUSD");
    expect(await this.busdToken.symbol()).to.equal("BUSD");
  });

  it("Should set Sacrifice and Bonus active", async function () {
    expect(await this.safuuXETH.isSacrificeActive()).to.equal(false);
    const saleStatus = await this.safuuXETH.setSacrificeStatus(true);
    expect(await this.safuuXETH.isSacrificeActive()).to.equal(true);

    expect(await this.safuuXETH.isBonusActive()).to.equal(false);
    await this.safuuXETH.activateBonus();
    expect(await this.safuuXETH.isBonusActive()).to.equal(true);
  });

  it("Should set Allowed Tokens", async function () {
    await this.safuuXETH.setAllowedTokens("USDC", this.usdcToken.address);
    expect(await this.safuuXETH.AllowedTokens("USDC")).to.equal(this.usdcToken.address);

    await this.safuuXETH.setAllowedTokens("USDT", this.usdtToken.address);
    expect(await this.safuuXETH.AllowedTokens("USDT")).to.equal(this.usdtToken.address);
  });

  it("Should deposit 20 ETH", async function() {
    const balBefore = await ethers.provider.getBalance(this.safuuWallet.address);
    console.log("ETH Before", balBefore);
    await this.safuuXETH.depositETH({
      value: ethers.utils.parseEther("200")
    });
    const balAfter = await ethers.provider.getBalance(this.safuuWallet.address);
    console.log("ETH After", balAfter);
    expect(Number(balAfter)).to.greaterThan(Number(balBefore));
  });

  it("Should approve USDC tokens", async function() {
    await this.usdcToken.approve(this.safuuXETH.address, ethers.utils.parseUnits("50000000", 18));
  });

  it("Should deposit 2000 USDC", async function() {
    const balBefore = await this.usdcToken.balanceOf(this.safuuWallet.address);
    console.log("USDC Before", balBefore);
    await this.safuuXETH.depositERC20("USDC", 2000);
    const balAfter = await this.usdcToken.balanceOf(this.safuuWallet.address);
    console.log("USDC After", balAfter);
    expect(Number(balAfter)).to.greaterThan(Number(balBefore));
  });
});
