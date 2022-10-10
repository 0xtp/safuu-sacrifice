const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const USDCToken = await hre.ethers.getContractFactory("ERC20Token");
  const usdcToken = await USDCToken.deploy("USDC", "USDC");
  await usdcToken.deployed();
  console.log("USDCToken deployed to:", usdcToken.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });