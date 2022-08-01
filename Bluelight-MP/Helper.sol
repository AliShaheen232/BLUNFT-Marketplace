//SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "./SafeMath.sol";

abstract contract Helper{
    using SafeMath for uint;
    
    function getPrivateUniqueKey(address nftContractAddress, uint256 tokenId) internal pure returns (bytes32){
        return keccak256(abi.encodePacked(nftContractAddress, tokenId));
    }
    function getFeePercentage(uint256 price, uint256 percent) internal pure returns (uint256){
        return price.mul(percent).div(100);
    } 
} 