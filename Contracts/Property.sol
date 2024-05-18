// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract Property is ERC721URIStorage{

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721( "Properties", "PROP" ) {}
    

    function mint(string memory _tokenURI)  external returns (uint) {
       
        _tokenIds.increment();
        uint newItemId = _tokenIds.current();

        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, _tokenURI);

        return newItemId;
        
    }

    function TotalListedProperties() public view returns (uint) {
        return _tokenIds.current();
    }
}