// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IChestChip } from "@biomesaw/world/src/prototypes/IChestChip.sol";
import { IForceFieldChip } from "@biomesaw/world/src/prototypes/IForceFieldChip.sol";
import { IDisplayChip } from "@biomesaw/world/src/prototypes/IDisplayChip.sol";

interface IChip is IChestChip {
  function changeAdmin(bytes32 entityId, address newAdmin) external;

  function setDisplayData(bytes32 entityId, string memory name, string memory description) external;

  function refillBuyShopBalance(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 refillAmount) external payable;

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) external;

  function setupBuySellShop(
    bytes32 chestEntityId,
    uint8 objectTypeId,
    uint256 initialItemAmount,
    uint256 initialCurrencyAmount,
    address paymentToken,
    uint256 feePercentage
  ) external payable;

  function adminWithdraw(address paymentToken, uint256 amount) external;
}
