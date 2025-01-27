// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAdmin } from "@biomesaw/experience/src/codegen/tables/ChipAdmin.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IWorld } from "./codegen/world/IWorld.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { CHIP_NAMESPACE } from "./Constants.sol";
import { IChip } from "./IChip.sol";

contract ChipSystem is System {
  function getChipContract() internal view returns (IChip) {
    return IChip(Metadata.getChipAddress());
  }

  function onlyAdmin(bytes32 entityId) internal view {
    require(ChipAdmin.get(entityId) == _msgSender(), "Only the admin can call this function");
  }

  function changeAdmin(bytes32 entityId, address newAdmin) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.changeAdmin(entityId, newAdmin);
  }

  function setDisplayData(bytes32 entityId, string memory name, string memory description) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.setDisplayData(entityId, name, description);
  }

  function setupBuyShop(
    bytes32 chestEntityId,
    uint8 buyObjectTypeId,
    uint256 buyPrice,
    uint256 buyAmount,
    address paymentToken
  ) public payable {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    IWorld(_world()).transferBalanceToAddress(
      WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE),
      address(this),
      _msgValue()
    );
    chip.setupBuyShop{ value: _msgValue() }(chestEntityId, buyObjectTypeId, buyPrice, buyAmount, paymentToken);
  }

  function setupSellShop(
    bytes32 chestEntityId,
    uint8 sellObjectTypeId,
    uint256 sellPrice,
    address paymentToken
  ) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    chip.setupSellShop(chestEntityId, sellObjectTypeId, sellPrice, paymentToken);
  }

  function setupBuySellShop(
    bytes32 chestEntityId,
    uint8 objectTypeId,
    uint256 buyPrice,
    uint256 buyAmount,
    uint256 sellPrice,
    address paymentToken
  ) public payable {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    IWorld(_world()).transferBalanceToAddress(
      WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE),
      address(this),
      _msgValue()
    );
    chip.setupBuySellShop{ value: _msgValue() }(
      chestEntityId,
      objectTypeId,
      buyPrice,
      buyAmount,
      sellPrice,
      paymentToken
    );
  }

  function changeBuyPrice(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 newPrice) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    chip.changeBuyPrice(chestEntityId, buyObjectTypeId, newPrice);
  }

  function changeSellPrice(bytes32 chestEntityId, uint8 sellObjectTypeId, uint256 newPrice) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    chip.changeSellPrice(chestEntityId, sellObjectTypeId, newPrice);
  }

  function buyMore(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 buyAmount) public payable {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    IWorld(_world()).transferBalanceToAddress(
      WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE),
      address(this),
      _msgValue()
    );
    chip.buyMore{ value: _msgValue() }(chestEntityId, buyObjectTypeId, buyAmount);
  }

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    chip.withdrawBuyShopBalance(chestEntityId, amount);
  }

  function destroyShop(bytes32 chestEntityId) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    chip.destroyShop(chestEntityId);
  }

  receive() external payable {
    // This function is executed when a contract receives plain Ether (without data)
  }
}
