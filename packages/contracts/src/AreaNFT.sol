// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AreaNFT is ERC721, Ownable {
  uint256 private _nextTokenId;

  constructor(
    string memory name,
    string memory symbol,
    address chipAddress
  ) ERC721(name, symbol) Ownable(chipAddress) {}

  function mint(address to) public onlyOwner {
    uint256 tokenId = _nextTokenId++;
    _safeMint(to, tokenId);
  }

  function burn(uint256 tokenId) public onlyOwner {
    _burn(tokenId);
  }
}
