// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SafuuToken is ERC20 {
    constructor() ERC20("Safuu", "SAFUU") {
        _mint(msg.sender, 10000000000000000000);
    }

    function mint(address _to, uint256 _count) external {
        _mint(_to, _count);
    }

    function decimals() public pure override returns (uint8) {
        return 5;
    }
}
