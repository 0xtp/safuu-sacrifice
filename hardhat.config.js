require("@nomiclabs/hardhat-waffle");

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

 const INFURA_URL = 'https://rinkeby.infura.io/v3/xxxx';
 const PRIVATE_KEY = '';
 
 module.exports = {
   solidity: "0.8.17",
   //networks:{
   //  rinkeby:{
   //    url: INFURA_URL,
   //    accounts:[`0x${PRIVATE_KEY}`]
   //  }
   //}
 };