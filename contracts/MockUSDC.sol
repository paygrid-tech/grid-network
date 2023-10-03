// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDC is ERC20, Ownable {
    constructor() ERC20("MockUSDC", "USDC") {}

    // Allows the owner to mint new tokens.
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
