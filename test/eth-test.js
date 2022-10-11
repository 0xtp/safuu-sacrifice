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

    const SafuuXETH = await ethers.getContractFactory("SafuuXSacrifice");
    this.safuuXETH = await SafuuXETH.deploy(this.wallet1.address, this.wallet2.address);
    await this.safuuXETH.deployed();
  });

  it("Should check properties match constructor", async function() {
    expect(await this.safuuToken.name()).to.equal("Safuu");
    expect(await this.safuuToken.symbol()).to.equal("SAFUU");

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
    expect(await this.safuuXETH.isSacrificeActive()).to.equal(false);
    const saleStatus = await this.safuuXETH.setSacrificeStatus(true);
    expect(await this.safuuXETH.isSacrificeActive()).to.equal(true);
  });

  it("Should set Allowed Tokens", async function () {
    await this.safuuXETH.setAllowedTokens("USDC", this.usdcToken.address);
    expect(await this.safuuXETH.AllowedTokens("USDC")).to.equal(this.usdcToken.address);

    await this.safuuXETH.setAllowedTokens("USDT", this.usdtToken.address);
    expect(await this.safuuXETH.AllowedTokens("USDT")).to.equal(this.usdtToken.address);

    await this.safuuXETH.setAllowedTokens("WBTC", this.wbtcToken.address);
    expect(await this.safuuXETH.AllowedTokens("WBTC")).to.equal(this.wbtcToken.address);
  });

  it("Should deposit 20 ETH into Wallet 1", async function() {
    const balBefore = await ethers.provider.getBalance(this.wallet1.address);
    console.log("ETH Before", balBefore);
    await this.safuuXETH.depositETH({
      value: ethers.utils.parseEther("20")
    });
    const balAfter = await ethers.provider.getBalance(this.wallet1.address);
    console.log("ETH After", balAfter);
    expect(Number(balAfter)).to.greaterThan(Number(balBefore));
  });

  it("Should approve USDC tokens", async function() {
    await this.usdcToken.approve(this.safuuXETH.address, 1000000000);
  });

  it("Should deposit 2000 USDC into Wallet 1", async function() {
    const balBefore = await this.usdcToken.balanceOf(this.wallet1.address);
    console.log("USDC Before", balBefore);
    await this.safuuXETH.depositERC20("USDC", 2000);
    const balAfter = await this.usdcToken.balanceOf(this.wallet1.address);
    console.log("USDC After", balAfter);
    expect(Number(balAfter)).to.greaterThan(Number(balBefore));
  });
});
