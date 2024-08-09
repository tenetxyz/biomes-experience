// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ShopToken is ERC20, Ownable {
  address private chipAddress;

  error ChipUnauthorizedAccount(address account);

  constructor(string memory name, string memory symbol, address _chipAddress) ERC20(name, symbol) Ownable(msg.sender) {
    chipAddress = _chipAddress;
  }

  modifier onlyChip() {
    if (chipAddress != _msgSender()) {
      revert ChipUnauthorizedAccount(_msgSender());
    }
    _;
  }

  function mint(address to, uint256 amount) public onlyChip {
    _mint(to, amount);
  }

  function burn(address account, uint256 value) public onlyChip {
    _burn(account, value);
  }

  function addAllowedSetup(address player) public onlyOwner {
    (bool success, ) = chipAddress.call(abi.encodeWithSignature("addAllowedSetup(address)", player));
    require(success, "ShopToken: addAllowedSetup failed");
  }

  function setChipAddress(address newChipAddress) public onlyOwner {
    chipAddress = newChipAddress;
  }

  function getChipAddress() public view returns (address) {
    return chipAddress;
  }
}
