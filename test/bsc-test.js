const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Deploy Tokens", function () {
  before(async function() {
    this.accounts = await ethers.getSigners();
    this.owner = this.accounts[0];
    this.wallet1 = this.accounts[1];
    this.wallet2 = this.accounts[2];

    const SafuuToken = await ethers.getContractFactory("SafuuToken");
    this.safuuToken = await SafuuToken.deploy();
    await this.safuuToken.deployed();

    const ETHToken = await ethers.getContractFactory("ERC20Token");
    this.ethToken = await ETHToken.deploy("ETH", "ETH");
    await this.ethToken.deployed();

    const USDCToken = await ethers.getContractFactory("ERC20Token");
    this.usdcToken = await USDCToken.deploy("USDC", "USDC");
    await this.usdcToken.deployed();

    const USDTToken = await ethers.getContractFactory("ERC20Token");
    this.usdtToken = await USDTToken.deploy("USDT", "USDT");
    await this.usdtToken.deployed();

    const BUSDToken = await ethers.getContractFactory("ERC20Token");
    this.busdToken = await BUSDToken.deploy("BUSD", "BUSD");
    await this.busdToken.deployed();

    const WBTCToken = await ethers.getContractFactory("ERC20Token");
    this.wbtcToken = await WBTCToken.deploy("WBTC", "WBTC");
    await this.wbtcToken.deployed();

    const SafuuXBSC = await ethers.getContractFactory("SafuuXSacrificeBSC");
    this.safuuXBSC = await SafuuXBSC.deploy(this.wallet1.address, this.wallet2.address);
    await this.safuuXBSC.deployed();
  });

  it("Should check properties match constructor", async function() {
    expect(await this.safuuToken.name()).to.equal("Safuu");
    expect(await this.safuuToken.symbol()).to.equal("SAFUU");

    expect(await this.ethToken.name()).to.equal("ETH");
    expect(await this.ethToken.symbol()).to.equal("ETH");

    expect(await this.usdcToken.name()).to.equal("USDC");
    expect(await this.usdcToken.symbol()).to.equal("USDC");

    expect(await this.usdtToken.name()).to.equal("USDT");
    expect(await this.usdtToken.symbol()).to.equal("USDT");

    expect(await this.busdToken.name()).to.equal("BUSD");
    expect(await this.busdToken.symbol()).to.equal("BUSD");

    expect(await this.wbtcToken.name()).to.equal("WBTC");
    expect(await this.wbtcToken.symbol()).to.equal("WBTC");
  });

  it("Should set Sacrifice active", async function () {
    expect(await this.safuuXBSC.isSacrificeActive()).to.equal(false);
    const saleStatus = await this.safuuXBSC.setSacrificeStatus(true);
    expect(await this.safuuXBSC.isSacrificeActive()).to.equal(true);
  });

  it("Should set Allowed Tokens", async function () {
    await this.safuuXBSC.setAllowedTokens("ETH", this.ethToken.address);
    expect(await this.safuuXBSC.AllowedTokens("ETH")).to.equal(this.ethToken.address);

    await this.safuuXBSC.setAllowedTokens("USDC", this.usdcToken.address);
    expect(await this.safuuXBSC.AllowedTokens("USDC")).to.equal(this.usdcToken.address);

    await this.safuuXBSC.setAllowedTokens("USDT", this.usdtToken.address);
    expect(await this.safuuXBSC.AllowedTokens("USDT")).to.equal(this.usdtToken.address);

    await this.safuuXBSC.setAllowedTokens("WBTC", this.wbtcToken.address);
    expect(await this.safuuXBSC.AllowedTokens("WBTC")).to.equal(this.wbtcToken.address);
  });

  it("Should deposit 20 BNB into Wallet 1", async function() {
    const balBefore = await ethers.provider.getBalance(this.wallet1.address);
    console.log("BNB Before", balBefore);
    await this.safuuXBSC.depositBNB({
      value: ethers.utils.parseEther("20")
    });
    const balAfter = await ethers.provider.getBalance(this.wallet1.address);
    console.log("BNB After", balAfter);
    expect(Number(balAfter)).to.greaterThan(Number(balBefore));
  });

  it("Should approve USDC tokens", async function() {
    await this.usdcToken.approve(this.safuuXBSC.address, 1000000000);
  });

  it("Should deposit 5000 USDC into Wallet 1", async function() {
    const balBefore = await this.usdcToken.balanceOf(this.wallet1.address);
    console.log("USDC Before", balBefore);
    await this.safuuXBSC.depositBEP20("USDC", 5000);
    const balAfter = await this.usdcToken.balanceOf(this.wallet1.address);
    console.log("USDC After", balAfter);
    expect(Number(balAfter)).to.greaterThan(Number(balBefore));
  });
});
