// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC20.sol"; 

contract BlueLightToken is ERC20 {
    uint private _totalSupply;
    constructor(uint totalSupply) ERC20("BlueLightToken", "BLU") {
        _mint (msg.sender, _totalSupply = totalSupply);
    }

}

