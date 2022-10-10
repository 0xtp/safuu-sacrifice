const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Deploy Tokens", function () {
  before(async function () {
    this.accounts = await ethers.getSigners();
    this.owner = this.accounts[0];

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
  });

  it("Should check properties match constructor", async function () {
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
});
