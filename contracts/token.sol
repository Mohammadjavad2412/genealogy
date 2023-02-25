pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DappToken is ERC20("MLM Token", "MLM") {
    constructor() public {
        _mint(msg.sender, 1000000000000000000000000);
    }
    