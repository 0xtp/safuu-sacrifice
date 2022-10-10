// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SafuuXSacrifice is Ownable {
    mapping(address => mapping(IERC20 => uint256)) public erc20Deposited;
    mapping(address => uint256) public ethDeposited;

    function depositETH() external payable {
        ethDeposited[msg.sender] += msg.value;
    }

    function depositERC20(IERC20 tokenAddress, uint256 amount) external {
        erc20Deposited[msg.sender][tokenAddress] += amount;
        tokenAddress.transferFrom(msg.sender, address(this), amount);
    }

    function withdrawETH() external onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    function withdrawERC20(IERC20 tokenContract, address to)
        external
        onlyOwner
    {
        tokenContract.transfer(to, tokenContract.balanceOf(address(this)));
    }
}
