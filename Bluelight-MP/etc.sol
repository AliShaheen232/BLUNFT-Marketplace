// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract userProfile{
    struct MyNFT{
        address nftAddr;
        uint256 tokenId;
        address owner;
        uint256 askAmount;
    }
    mapping(address => MyNFT[]) public nftPointer;
    // mapping(address => bytes32[]) public userNfts;
   
    // function getPrivateUniqueKey(address owner, address nftContractAddress, uint256 tokenId) internal pure returns (bytes32 NFTUniKey){
    //     return keccak256(abi.encodePacked(owner, nftContractAddress, tokenId));
    // }
    
    function setNftData(address nftContractAddress, uint256 tokenId, uint value) external{
        // IERC721 nftContract = IERC721(nftContractAddress); ********* for check of ownership of this nft.
        // require(nftContract.ownerOf(tokenId) == msg.sender, "your not the owner of this nft");
        // address contractAddress;
        // uint256 tokenId;
        // address newOwner;
        // uint256 askAmount;
        
        // bytes32 uniqueKey = getPrivateUniqueKey(msg.sender, nftContractAddress,tokenId);
        MyNFT memory myNft ; 
        myNft.nftAddr = nftContractAddress;
        myNft.tokenId = tokenId;
        myNft.owner = msg.sender;
        myNft.askAmount = value;
        nftPointer[msg.sender].push(myNft);
        // userNfts[msg.sender].push(uniqueKey);      
    }
    function getMyNFT() external view returns(MyNFT[] memory){
        return nftPointer[msg.sender];
    }

}
// address contractAddress, uint256 tokenId, address newOwner, uint256 askAmount