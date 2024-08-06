// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ShopToken is ERC20, Ownable {
  address deployer;

  constructor(string memory name, string memory symbol, address chipAddress) ERC20(name, symbol) Ownable(chipAddress) {
    deployer = msg.sender;
  }

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }

  function burn(address account, uint256 value) public onlyOwner {
    _burn(account, value);
  }

  function addAllowedSetup(address player) public {
    require(msg.sender == deployer, "ShopToken: only deployer can add allowed setup");
    (bool success, ) = owner().call(abi.encodeWithSignature("addAllowedSetup(address)", player));
    require(success, "ShopToken: addAllowedSetup failed");
  }
}
