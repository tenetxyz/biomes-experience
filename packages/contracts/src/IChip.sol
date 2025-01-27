// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IChestChip } from "@biomesaw/world/src/prototypes/IChestChip.sol";
import { IForceFieldChip } from "@biomesaw/world/src/prototypes/IForceFieldChip.sol";
import { IDisplayChip } from "@biomesaw/world/src/prototypes/IDisplayChip.sol";

interface IChip is IChestChip {
  function changeAdmin(bytes32 entityId, address newAdmin) external;

  function setDisplayData(bytes32 entityId, string memory name, string memory description) external;

  function configurePipeAccess(
    bytes32 chestEntityId,
    bytes32 callerEntityId,
    bool depositAllowed,
    bool withdrawAllowed
  ) external;

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) external;

  function setupBuySellShop(
    bytes32 chestEntityId,
    uint8 objectTypeId,
    uint16 initialItemAmount,
    uint256 initialCurrencyAmount,
    address paymentToken,
    uint256 feePercentage
  ) external payable;

  function getBuyPrice(
    uint256 itemExchangeConstant,
    uint256 chestBalance,
    uint256 feePercentage,
    uint256 numItemsInChest,
    uint256 buyAmount
  ) external view returns (uint256);

  function getSellPrice(
    uint256 itemExchangeConstant,
    uint256 chestBalance,
    uint256 numItemsInChest,
    uint256 sellAmount
  ) external view returns (uint256);

  function adminTransfer(address paymentToken, uint256 amount, address receiver) external;
}
