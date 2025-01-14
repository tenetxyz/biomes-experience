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

import { CHIP_NAMESPACE, BUY_EXCHANGE_ID, SELL_EXCHANGE_ID } from "./Constants.sol";
import { IChip } from "./IChip.sol";
import { ExchangeInfo, ExchangeInfoData } from "@biomesaw/experience/src/codegen/tables/ExchangeInfo.sol";
import { decodeAddressExchangeResourceId, decodeObjectExchangeResourceId } from "@biomesaw/experience/src/utils/ExchangeUtils.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";

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
    ExchangeFee.set(chestEntityId, objectTypeId, feePercentage);
  }

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    chip.withdrawBuyShopBalance(chestEntityId, amount);
  }

  function setupBuySellShop(
    bytes32 chestEntityId,
    uint8 objectTypeId,
    uint16 initialItemAmount,
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

  // For compatibility with old setupBuySellShop
  function setupBuySellShop(
    bytes32 chestEntityId,
    uint8 objectTypeId,
    uint256 initialItemAmount,
    uint256 initialCurrencyAmount,
    address paymentToken,
    uint256 feePercentage
  ) public payable {
    setupBuySellShop(
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

    ExchangeInfoData memory sellExchangeInfo = ExchangeInfo.get(chestEntityId, SELL_EXCHANGE_ID);
    uint8 exchangeObjectTypeId = decodeObjectExchangeResourceId(sellExchangeInfo.outResourceId);
    require(exchangeObjectTypeId != NullObjectTypeId, "Chest is not set up");

    uint16 newNumItemsInChest = getCount(chestEntityId, exchangeObjectTypeId);
    require(buyAmount <= newNumItemsInChest, "Insufficient items in chest");
    newNumItemsInChest -= buyAmount;
    require(newNumItemsInChest > 0, "Chest must have at least one item");

    uint256 itemExchangeConstant = Exchange.get(chestEntityId, exchangeObjectTypeId);
    uint256 newBalance = itemExchangeConstant / newNumItemsInChest;

    ExchangeInfoData memory buyExchangeInfo = ExchangeInfo.get(chestEntityId, BUY_EXCHANGE_ID);
    require(newBalance >= buyExchangeInfo.outMaxAmount, "Insufficient balance in chest");
    uint256 shopTotalPrice = newBalance - buyExchangeInfo.outMaxAmount;

    uint256 feePercentage = ExchangeFee.get(chestEntityId, exchangeObjectTypeId);
    uint256 totalFee = (shopTotalPrice * feePercentage) / 100;
    shopTotalPrice += totalFee;

    return shopTotalPrice;
  }

  function getSellPrice(bytes32 chestEntityId, uint16 sellAmount) public view returns (uint256) {
    if (sellAmount == 0) {
      return 0;
    }

    ExchangeInfoData memory buyExchangeInfo = ExchangeInfo.get(chestEntityId, BUY_EXCHANGE_ID);
    uint8 exchangeObjectTypeId = decodeObjectExchangeResourceId(buyExchangeInfo.inResourceId);
    require(exchangeObjectTypeId != NullObjectTypeId, "Chest is not set up");

    uint16 newNumItemsInChest = getCount(chestEntityId, exchangeObjectTypeId);
    newNumItemsInChest += sellAmount;

    uint256 itemExchangeConstant = Exchange.get(chestEntityId, exchangeObjectTypeId);

    require(newNumItemsInChest > 0, "Chest must have at least one item");
    uint256 newBalance = itemExchangeConstant / newNumItemsInChest;

    require(buyExchangeInfo.outMaxAmount >= newBalance, "Insufficient balance in chest");
    uint256 shopTotalPrice = buyExchangeInfo.outMaxAmount - newBalance;

    return shopTotalPrice;
  }

  function getBuySellPrices(
    bytes32 chestEntityId,
    uint16 buyAmount,
    uint16 sellAmount
  ) public view returns (uint256, uint256) {
    return (getBuyPrice(chestEntityId, buyAmount), getSellPrice(chestEntityId, sellAmount));
  }

  function refillBuyShopBalance(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 refillAmount) public payable {
    revert("Deprecated");
  }

  receive() external payable {
    // This function is executed when a contract receives plain Ether (without data)
  }
}
