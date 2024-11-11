// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IWorld } from "./codegen/world/IWorld.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { Fees } from "./codegen/tables/Fees.sol";
import { CHIP_NAMESPACE } from "./Constants.sol";
import { IChip } from "./IChip.sol";

contract ChipSystem is System {
  function getChipContract() internal view returns (IChip) {
    return IChip(Metadata.getChipAddress());
  }

  function onlyAttacher(bytes32 entityId) internal view {
    require(ChipAttachment.getAttacher(entityId) == _msgSender(), "Only the attacher can call this function");
  }

  function setDisplayData(bytes32 entityId, string memory name, string memory description) public {
    onlyAttacher(entityId);
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
    onlyAttacher(chestEntityId);
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
    onlyAttacher(chestEntityId);
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
    onlyAttacher(chestEntityId);
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
    onlyAttacher(chestEntityId);
    IChip chip = getChipContract();
    chip.changeBuyPrice(chestEntityId, buyObjectTypeId, newPrice);
  }

  function changeSellPrice(bytes32 chestEntityId, uint8 sellObjectTypeId, uint256 newPrice) public {
    onlyAttacher(chestEntityId);
    IChip chip = getChipContract();
    chip.changeSellPrice(chestEntityId, sellObjectTypeId, newPrice);
  }

  function refillBuyShopBalance(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 refillAmount) public payable {
    onlyAttacher(chestEntityId);
    IChip chip = getChipContract();
    IWorld(_world()).transferBalanceToAddress(
      WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE),
      address(this),
      _msgValue()
    );
    chip.refillBuyShopBalance{ value: _msgValue() }(chestEntityId, buyObjectTypeId, refillAmount);
  }

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) public {
    onlyAttacher(chestEntityId);
    IChip chip = getChipContract();
    chip.withdrawBuyShopBalance(chestEntityId, amount);
  }

  function destroyShop(bytes32 chestEntityId, uint8 objectTypeId) public {
    onlyAttacher(chestEntityId);
    IChip chip = getChipContract();
    chip.destroyShop(chestEntityId, objectTypeId);
  }

  receive() external payable {
    // This function is executed when a contract receives plain Ether (without data)
  }
}
