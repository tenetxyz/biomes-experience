// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { WorldContextConsumerLib } from "@latticexyz/world/src/WorldContext.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { Hook } from "@latticexyz/store/src/Hook.sol";
import { IERC165 } from "@latticexyz/world/src/IERC165.sol";
import { ICustomUnregisterDelegation } from "@latticexyz/world/src/ICustomUnregisterDelegation.sol";
import { IOptionalSystemHook } from "@latticexyz/world/src/IOptionalSystemHook.sol";
import { BEFORE_CALL_SYSTEM, AFTER_CALL_SYSTEM, ALL } from "@latticexyz/world/src/systemHookTypes.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { OptionalSystemHooks } from "@latticexyz/world/src/codegen/tables/OptionalSystemHooks.sol";
import { IChestChip } from "@biomesaw/world/src/prototypes/IChestChip.sol";
import { IForceFieldChip } from "@biomesaw/world/src/prototypes/IForceFieldChip.sol";

import { IWorld } from "@biomesaw/world/src/codegen/world/IWorld.sol";
import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { voxelCoordsAreEqual, inSurroundingCube } from "@biomesaw/utils/src/VoxelCoordUtils.sol";
import { IWorld as IExperienceWorld } from "@biomesaw/experience/src/codegen/world/IWorld.sol";
import { ExperienceMetadata, ExperienceMetadataData } from "@biomesaw/experience/src/codegen/tables/ExperienceMetadata.sol";
import { ChipMetadata, ChipMetadataData } from "@biomesaw/experience/src/codegen/tables/ChipMetadata.sol";
import { ChipType } from "@biomesaw/experience/src/codegen/common.sol";
import { ShopType, ShopTxType } from "@biomesaw/experience/src/codegen/common.sol";

// Available utils, remove the ones you don't need
// See ObjectTypeIds.sol for all available object types
import { PlayerObjectID, AirObjectID, DirtObjectID, ChestObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { getBuildArgs, getMineArgs, getMoveArgs, getHitArgs, getDropArgs, getTransferArgs, getCraftArgs, getEquipArgs, getLoginArgs, getSpawnArgs } from "@biomesaw/experience/src/utils/HookUtils.sol";
import { getSystemId, isSystemId, callBuild, callMine, callMove, callHit, callDrop, callTransfer, callCraft, callEquip, callUnequip, callLogin, callLogout, callSpawn, callActivate } from "@biomesaw/experience/src/utils/DelegationUtils.sol";
import { hasBeforeAndAfterSystemHook, getObjectTypeAtCoord, getTerrainBlock, getEntityAtCoord, getPosition, getObjectType, getMiningDifficulty, getStackable, getDamage, getDurability, isTool, isBlock, getEntityFromPlayer, getPlayerFromEntity, getEquipped, getHealth, getStamina, getIsLoggedOff, getLastHitTime, getInventoryTool, getInventoryObjects, getNumInventoryObjects, getCount, getNumSlotsUsed, getNumUsesLeft } from "@biomesaw/experience/src/utils/EntityUtils.sol";
import { Area, insideArea, insideAreaIgnoreY, getEntitiesInArea, getArea } from "@biomesaw/experience/src/utils/AreaUtils.sol";
import { Build, BuildWithPos, buildExistsInWorld, buildWithPosExistsInWorld, getBuild, getBuildWithPos } from "@biomesaw/experience/src/utils/BuildUtils.sol";
import { weiToString, getEmptyBlockOnGround } from "@biomesaw/experience/src/utils/GameUtils.sol";
import { setExperienceMetadata, setJoinFee, deleteExperienceMetadata, setNotification, deleteNotifications, setStatus, deleteStatus, setRegisterMsg, deleteRegisterMsg, setUnregisterMsg, deleteUnregisterMsg } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setPlayers, pushPlayers, popPlayers, updatePlayers, deletePlayers, setArea, deleteArea, setBuild, deleteBuild, setBuildWithPos, deleteBuildWithPos, setCountdown, setCountdownEndTimestamp, setCountdownEndBlock, setTokenMetadata, deleteTokenMetadata, setNFTMetadata, deleteNFTMetadata, setTokens, pushTokens, popTokens, updateTokens, deleteTokens, setNfts, pushNfts, popNfts, updateNfts, deleteNfts } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setChipMetadata, deleteChipMetadata, setChipAttacher, deleteChipAttacher } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setShop, deleteShop, setBuyShop, setSellShop, setShopBalance, setBuyPrice, setSellPrice, setShopObjectTypeId, emitShopNotif, deleteShopNotif } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setChestMetadata, setChestName, setChestDescription, deleteChestMetadata, setForceFieldMetadata, setForceFieldName, setForceFieldDescription, deleteForceFieldMetadata, setForceFieldApprovals, deleteForceFieldApprovals, setFFApprovedPlayers, pushFFApprovedPlayer, popFFApprovedPlayer, updateFFApprovedPlayer, setFFApprovedNFT, pushFFApprovedNFT, popFFApprovedNFT, updateFFApprovedNFT } from "@biomesaw/experience/src/utils/ChipUtils.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { AllowedSetup } from "./codegen/tables/AllowedSetup.sol";
import { Exchange } from "./codegen/tables/Exchange.sol";
import { Tokens } from "@biomesaw/experience/src/codegen/tables/Tokens.sol";
import { ChestMetadataData } from "@biomesaw/experience/src/codegen/tables/ChestMetadata.sol";
import { ItemShop, ItemShopData } from "@biomesaw/experience/src/codegen/tables/ItemShop.sol";
import { ShopType } from "@biomesaw/experience/src/codegen/common.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";
import { ItemShopNotifData } from "@biomesaw/experience/src/codegen/tables/ItemShopNotif.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { SilverBarObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";

import { LinearVRGDA } from "./vrgda/LinearVRGDA.sol";

/// @dev Takes an integer amount of seconds and converts it to a wad amount of three days.
/// @dev Will not revert on overflow, only use where overflow is not possible.
/// @dev Not meant for negative second amounts, it assumes x is positive.
function toThreeDaysWadUnsafe(uint256 x) pure returns (int256 r) {
  /// @solidity memory-safe-assembly
  assembly {
    // Multiply x by 1e18 and then divide it by 259200.
    r := div(mul(x, 1000000000000000000), 259200)
  }
}

contract Chip is IChestChip, LinearVRGDA, Ownable {
  // The object this chip is for
  uint8 public immutable objectTypeId;

  constructor(
    address _biomeWorldAddress,
    uint8 _objectTypeId,
    int256 _targetPrice,
    int256 _priceDecayPercent,
    int256 _perTimeUnit
  ) LinearVRGDA(_targetPrice, _priceDecayPercent, _perTimeUnit) Ownable(msg.sender) {
    require(_targetPrice > 0, "Target price must be greater than 0");

    objectTypeId = _objectTypeId;

    StoreSwitch.setStoreAddress(_biomeWorldAddress);
  }

  function setDisplayData(bytes32 chestEntityId, string memory name, string memory description) public {
    require(
      ChipAttachment.getAttacher(chestEntityId) == msg.sender,
      "Only the attacher can set the chest display data"
    );
    setChestMetadata(chestEntityId, ChestMetadataData({ name: name, description: description }));
  }

  function getBuyUnitPrice(bytes32 chestEntityId) public view returns (uint256) {
    // 5% markup on the current price
    return (Exchange.getPrice(objectTypeId) * 105) / 100;
  }

  function getSellUnitPrice(bytes32 chestEntityId) public view returns (uint256) {
    // 5% discount from the current price
    return (Exchange.getPrice(objectTypeId) * 95) / 100;
  }

  function getBuySellUnitPrices(bytes32 chestEntityId) public view returns (uint256, uint256) {
    return (getBuyUnitPrice(chestEntityId), getSellUnitPrice(chestEntityId));
  }

  function doWithdraw(address player, bytes32 chestEntityId, uint256 amount) internal returns (uint256) {
    require(amount > 0, "Amount must be greater than 0");
    uint256 currentBalance = ItemShop.getBalance(chestEntityId);
    require(currentBalance >= amount, "Insufficient balance");
    uint256 newBalance = currentBalance - amount;

    address paymentToken = ItemShop.getPaymentToken(chestEntityId);
    if (paymentToken == address(0)) {
      (bool sent, ) = player.call{ value: amount }("");
      require(sent, "Failed to send Ether");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transfer(player, amount), "Failed to transfer tokens");
    }

    return newBalance;
  }

  function refillBuyShopBalance(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 refillAmount) public payable {
    require(ItemShop.getObjectTypeId(chestEntityId) == buyObjectTypeId, "Chest is not set up");

    address paymentToken = ItemShop.getPaymentToken(chestEntityId);

    uint256 newBalance = ItemShop.getBalance(chestEntityId) + refillAmount;
    setShopBalance(chestEntityId, newBalance);

    if (paymentToken == address(0)) {
      require(msg.value == refillAmount, "Insufficient Ether sent");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transferFrom(msg.sender, address(this), refillAmount), "Failed to transfer tokens");
    }
  }

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can withdraw the balance");
    uint256 newBalance = doWithdraw(msg.sender, chestEntityId, amount);
    setShopBalance(chestEntityId, newBalance);
  }

  function adminWithdraw(address paymentToken, uint256 amount) public onlyOwner {
    if (paymentToken == address(0)) {
      (bool sent, ) = owner().call{ value: amount }("");
      require(sent, "Failed to send Ether");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transfer(owner(), amount), "Failed to transfer tokens");
    }
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IChestChip).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function onAttached(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {
    require(getNumInventoryObjects(entityId) == 0, "Chest must be empty");
    address player = getPlayerFromEntity(playerEntityId);
    setChipAttacher(entityId, player);

    require(AllowedSetup.get(player), "Not allowed to use this chip");

    address tokenAddress = Metadata.getExchangeToken(objectTypeId);

    // Not setup yet
    if (Exchange.getLastPurchaseTime(objectTypeId) == 0) {
      Exchange.setLastPurchaseTime(objectTypeId, block.timestamp);
    }

    setShop(
      entityId,
      ItemShopData({
        shopType: ShopType.BuySell,
        objectTypeId: objectTypeId,
        buyPrice: 0,
        sellPrice: 0,
        balance: 0,
        paymentToken: tokenAddress
      })
    );
  }

  function onDetached(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {
    uint8 shopObjectTypeId = ItemShop.getObjectTypeId(entityId);

    address previousOwner = ChipAttachment.getAttacher(entityId);
    uint256 currentBalance = ItemShop.getBalance(entityId);
    if (currentBalance > 0) {
      doWithdraw(previousOwner, entityId, currentBalance);
    }

    if (shopObjectTypeId != NullObjectTypeId) {
      uint16 currentSupplyInChest = getCount(entityId, shopObjectTypeId);
      if (currentSupplyInChest > 0) {
        // Consider these items as having been withdraw from the chest
        // ie they are no longer part of the supply
        Exchange.setSold(objectTypeId, Exchange.getSold(objectTypeId) + currentSupplyInChest);
      }

      // Clear existing shop data
      deleteShop(entityId);
    }

    deleteChestMetadata(entityId);
    deleteChipAttacher(entityId);
  }

  function onPowered(bytes32 playerEntityId, bytes32 entityId, uint16 numBattery) public override onlyBiomeWorld {}

  function onChipHit(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {}

  function onTransfer(
    bytes32 srcEntityId,
    bytes32 dstEntityId,
    uint8 transferObjectTypeId,
    uint16 numToTransfer,
    bytes32 toolEntityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool) {
    bool isDeposit = getObjectType(srcEntityId) == PlayerObjectID;
    bytes32 chestEntityId = isDeposit ? dstEntityId : srcEntityId;
    ItemShopData memory chestShopData = ItemShop.get(chestEntityId);
    if (chestShopData.objectTypeId != transferObjectTypeId) {
      return false;
    }
    if (toolEntityId != bytes32(0)) {
      require(
        getNumUsesLeft(toolEntityId) == getDurability(chestShopData.objectTypeId),
        "Tool must have full durability"
      );
    }

    address owner = ChipAttachment.getAttacher(chestEntityId);
    require(owner != address(0), "Chest does not exist");
    address player = getPlayerFromEntity(isDeposit ? srcEntityId : dstEntityId);
    require(player != address(0), "Player does not exist");
    if (player == owner) {
      return true;
    }

    uint256 shopTotalPrice = isDeposit
      ? getSellUnitPrice(chestEntityId) * numToTransfer
      : getBuyUnitPrice(chestEntityId) * numToTransfer;

    uint256 newSold = Exchange.getSold(objectTypeId);
    uint256 lastPurchaseTime = Exchange.getLastPurchaseTime(objectTypeId);

    if (isDeposit) {
      newSold = numToTransfer < newSold ? newSold - numToTransfer : 0;

      // Check if there is enough balance in the chest
      uint256 balance = chestShopData.balance;
      require(balance >= shopTotalPrice, "Insufficient balance in chest");
      uint256 newBalance = balance - shopTotalPrice;
      setShopBalance(chestEntityId, newBalance);

      if (chestShopData.paymentToken == address(0)) {
        (bool sent, ) = player.call{ value: shopTotalPrice }("");
        require(sent, "Failed to send Ether");
      } else {
        IERC20 token = IERC20(chestShopData.paymentToken);
        require(token.transfer(player, shopTotalPrice), "Failed to transfer tokens");
      }
    } else {
      newSold += numToTransfer;
      Exchange.setLastPurchaseTime(objectTypeId, block.timestamp);

      uint256 newBalance = chestShopData.balance + shopTotalPrice;
      setShopBalance(chestEntityId, newBalance);

      if (chestShopData.paymentToken == address(0)) {
        require(msg.value == shopTotalPrice, "Insufficient Ether sent");
      } else {
        IERC20 token = IERC20(chestShopData.paymentToken);
        require(token.transferFrom(player, address(this), shopTotalPrice), "Failed to transfer tokens");
      }
    }
    Exchange.setSold(objectTypeId, newSold);

    {
      // Update price
      int256 timeSinceLastPurchase = toThreeDaysWadUnsafe(block.timestamp - lastPurchaseTime);
      uint256 vrgdaPrice = getVRGDAPrice(timeSinceLastPurchase, newSold);
      Exchange.setPrice(objectTypeId, vrgdaPrice);
    }

    emitShopNotif(
      chestEntityId,
      ItemShopNotifData({
        player: player,
        shopTxType: isDeposit ? ShopTxType.Sell : ShopTxType.Buy,
        objectTypeId: chestShopData.objectTypeId,
        price: shopTotalPrice,
        amount: numToTransfer,
        paymentToken: chestShopData.paymentToken
      })
    );

    return true;
  }
}
