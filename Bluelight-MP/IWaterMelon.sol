//SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

interface IWaterMelon{
    function setUserDashboard (address userDashboard) external;
    function setERC20Token (address erc20Token) external; 
    function setFeePercent (uint256 value) external;
    function setPlatformAddr (address payable _addr) external;
    function listNFTForFixedType(address nftContractAddress, uint256 tokenId, uint256 price) external;
    function listNFTForAuctionType(address nftContractAddress, uint256 tokenId, uint256 price, uint256 maxPrice, uint256 auctionEndTime) external;
    function buyCurFixNFT(address nftContractAddress, uint256 tokenId ) external payable;
    function buyTokenFixNFT(address nftContractAddress, uint256 tokenId, uint price) external; 
    function cancel(address nftContractAddress,  uint256 tokenId) external;
    function bidTokenNFT(address nftContractAddress, uint tokenId, uint amount) external;
    function auctionTokenTimeOver(address nftContractAddress, uint256 tokenId) external ;   
}