// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC721.sol";
import "./ERC721URIStorage.sol";
import "./Ownable.sol";

contract BlueLightNFT is ERC721, ERC721URIStorage{
    constructor() ERC721("Blue Light NFT", "BLU-NFT") {}

    function _baseURI() internal pure override returns (string memory) {
        return "www.ammag.com/";
    }

    function safeMint( uint256 tokenId, uint256 royality, string memory uri) public{
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
        setRoyalityDetails(tokenId,royality,msg.sender);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)  {
        return super.tokenURI(tokenId);
    }
}