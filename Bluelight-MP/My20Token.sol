// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC20.sol"; 
// import "./access/Ownable.sol";

contract My20Token is ERC20 {
    uint private _totalSupply;
    constructor(uint totalSupply) ERC20("Quinn", "QIN") {
        _mint (msg.sender, _totalSupply = totalSupply);
    }

}

