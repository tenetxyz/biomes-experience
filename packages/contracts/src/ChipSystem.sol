// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAdmin } from "@biomesaw/experience/src/codegen/tables/ChipAdmin.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";

import { ItemShop, ItemShopData } from "@biomesaw/experience/src/codegen/tables/ItemShop.sol";

import { getCount } from "@biomesaw/experience/src/utils/EntityUtils.sol";

import { IWorld } from "./codegen/world/IWorld.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { ExchangeFee } from "./codegen/tables/ExchangeFee.sol";
import { Exchange } from "./codegen/tables/Exchange.sol";

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

  function setExchangeFee(bytes32 chestEntityId, uint8 objectTypeId, uint256 feePercentage) public {
    onlyAdmin(chestEntityId);
    require(ItemShop.getObjectTypeId(chestEntityId) == objectTypeId, "Chest is not set up");

    ExchangeFee.set(chestEntityId, objectTypeId, feePercentage);
  }

  function refillBuyShopBalance(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 refillAmount) public payable {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    IWorld(_world()).transferBalanceToAddress(
      WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE),
      address(this),
      _msgValue()
    );
    chip.refillBuyShopBalance{ value: _msgValue() }(chestEntityId, buyObjectTypeId, refillAmount);
  }

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    chip.withdrawBuyShopBalance(chestEntityId, amount);
  }

  function setupBuySellShop(
    bytes32 chestEntityId,
    uint8 objectTypeId,
    uint256 initialItemAmount,
    uint256 initialCurrencyAmount,
    address paymentToken,
    uint256 feePercentage
  ) public payable {
    IChip chip = getChipContract();
    IWorld(_world()).transferBalanceToAddress(
      WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE),
      address(this),
      _msgValue()
    );
    chip.setupBuySellShop{ value: _msgValue() }(
      chestEntityId,
      objectTypeId,
      initialItemAmount,
      initialCurrencyAmount,
      paymentToken,
      feePercentage
    );
  }

  function getExchangeFee(bytes32 chestEntityId, uint8 objectTypeId) public view returns (uint256) {
    return ExchangeFee.get(chestEntityId, objectTypeId);
  }

  function getBuyPrice(bytes32 chestEntityId, uint16 buyAmount) public view returns (uint256) {
    if (buyAmount == 0) {
      return 0;
    }

    ItemShopData memory chestShopData = ItemShop.get(chestEntityId);
    require(chestShopData.objectTypeId > 0, "Chest is not set up");

    uint16 newNumItemsInChest = getCount(chestEntityId, chestShopData.objectTypeId);
    require(buyAmount <= newNumItemsInChest, "Insufficient items in chest");
    newNumItemsInChest -= buyAmount;
    require(newNumItemsInChest > 0, "Chest must have at least one item");

    uint256 itemExchangeConstant = Exchange.get(chestEntityId, chestShopData.objectTypeId);
    uint256 newBalance = itemExchangeConstant / newNumItemsInChest;

    require(newBalance >= chestShopData.balance, "Insufficient balance in chest");
    uint256 shopTotalPrice = newBalance - chestShopData.balance;

    uint256 feePercentage = ExchangeFee.get(chestEntityId, chestShopData.objectTypeId);
    uint256 totalFee = (shopTotalPrice * feePercentage) / 100;
    shopTotalPrice += totalFee;

    return shopTotalPrice;
  }

  function getSellPrice(bytes32 chestEntityId, uint16 sellAmount) public view returns (uint256) {
    if (sellAmount == 0) {
      return 0;
    }

    ItemShopData memory chestShopData = ItemShop.get(chestEntityId);
    require(chestShopData.objectTypeId > 0, "Chest is not set up");

    uint16 newNumItemsInChest = getCount(chestEntityId, chestShopData.objectTypeId);
    newNumItemsInChest += sellAmount;

    uint256 itemExchangeConstant = Exchange.get(chestEntityId, chestShopData.objectTypeId);

    require(newNumItemsInChest > 0, "Chest must have at least one item");
    uint256 newBalance = itemExchangeConstant / newNumItemsInChest;

    require(chestShopData.balance >= newBalance, "Insufficient balance in chest");
    uint256 shopTotalPrice = chestShopData.balance - newBalance;

    return shopTotalPrice;
  }

  function getBuySellPrices(
    bytes32 chestEntityId,
    uint16 buyAmount,
    uint16 sellAmount
  ) public view returns (uint256, uint256) {
    return (getBuyPrice(chestEntityId, buyAmount), getSellPrice(chestEntityId, sellAmount));
  }

  receive() external payable {
    // This function is executed when a contract receives plain Ether (without data)
  }
}
