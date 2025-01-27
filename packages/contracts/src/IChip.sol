// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IChestChip } from "@biomesaw/world/src/prototypes/IChestChip.sol";
import { IForceFieldChip } from "@biomesaw/world/src/prototypes/IForceFieldChip.sol";
import { IDisplayChip } from "@biomesaw/world/src/prototypes/IDisplayChip.sol";

interface IChip is IChestChip {
  function changeAdmin(bytes32 entityId, address newAdmin) external;

  function setDisplayData(bytes32 entityId, string memory name, string memory description) external;

  function setupBuyShop(
    bytes32 chestEntityId,
    uint8 buyObjectTypeId,
    uint256 buyPrice,
    uint256 buyAmount,
    address paymentToken
  ) external payable;

  function setupSellShop(
    bytes32 chestEntityId,
    uint8 sellObjectTypeId,
    uint256 sellPrice,
    address paymentToken
  ) external;

  function setupBuySellShop(
    bytes32 chestEntityId,
    uint8 objectTypeId,
    uint256 buyPrice,
    uint256 buyAmount,
    uint256 sellPrice,
    address paymentToken
  ) external payable;

  function changeBuyPrice(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 newPrice) external;

  function changeSellPrice(bytes32 chestEntityId, uint8 sellObjectTypeId, uint256 newPrice) external;

  function buyMore(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 buyAmount) external payable;

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) external;

  function destroyShop(bytes32 chestEntityId) external;

  function adminTransfer(address paymentToken, uint256 amount, address receiver) external;
}
