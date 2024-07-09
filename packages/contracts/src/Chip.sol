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
import { IChip } from "@biomesaw/world/src/prototypes/IChip.sol";

import { IWorld } from "@biomesaw/world/src/codegen/world/IWorld.sol";
import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { voxelCoordsAreEqual, inSurroundingCube } from "@biomesaw/utils/src/VoxelCoordUtils.sol";
import { IWorld as IExperienceWorld } from "@biomesaw/experience/src/codegen/world/IWorld.sol";
import { ExperienceMetadata, ExperienceMetadataData } from "@biomesaw/experience/src/codegen/tables/ExperienceMetadata.sol";
import { ChipMetadata, ChipMetadataData } from "@biomesaw/experience/src/codegen/tables/ChipMetadata.sol";
import { ChipType } from "@biomesaw/experience/src/codegen/common.sol";

// Available utils, remove the ones you don't need
// See ObjectTypeIds.sol for all available object types
import { PlayerObjectID, AirObjectID, DirtObjectID, ChestObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { getBuildArgs, getMineArgs, getMoveArgs, getHitArgs, getDropArgs, getTransferArgs, getCraftArgs, getEquipArgs, getLoginArgs, getSpawnArgs } from "@biomesaw/experience/src/utils/HookUtils.sol";
import { getSystemId, isSystemId, callBuild, callMine, callMove, callHit, callDrop, callTransfer, callCraft, callEquip, callUnequip, callLogin, callLogout, callSpawn, callActivate } from "@biomesaw/experience/src/utils/DelegationUtils.sol";
import { hasBeforeAndAfterSystemHook, getObjectTypeAtCoord, getTerrainBlock, getEntityAtCoord, getPosition, getObjectType, getMiningDifficulty, getStackable, getDamage, getDurability, isTool, isBlock, getEntityFromPlayer, getPlayerFromEntity, getEquipped, getHealth, getStamina, getIsLoggedOff, getLastHitTime, getInventoryTool, getInventoryObjects, getCount, getNumSlotsUsed, getNumUsesLeft } from "@biomesaw/experience/src/utils/EntityUtils.sol";
import { Area, insideArea, insideAreaIgnoreY, getEntitiesInArea, getArea } from "@biomesaw/experience/src/utils/AreaUtils.sol";
import { Build, BuildWithPos, buildExistsInWorld, buildWithPosExistsInWorld, getBuild, getBuildWithPos } from "@biomesaw/experience/src/utils/BuildUtils.sol";
import { weiToString, getEmptyBlockOnGround } from "@biomesaw/experience/src/utils/GameUtils.sol";
import { setExperienceMetadata, setJoinFee, deleteExperienceMetadata, setNotification, deleteNotifications, setStatus, deleteStatus, setRegisterMsg, deleteRegisterMsg, setUnregisterMsg, deleteUnregisterMsg } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setPlayers, pushPlayers, popPlayers, updatePlayers, deletePlayers, setArea, deleteArea, setBuild, deleteBuild, setBuildWithPos, deleteBuildWithPos, setCountdown, setCountdownEndTimestamp, setCountdownEndBlock, setTokens, pushTokens, popTokens, updateTokens, deleteTokens, setNfts, pushNfts, popNfts, updateNfts, deleteNfts } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setChipMetadata, deleteChipMetadata, setChipAttacher, deleteChipAttacher } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setShop, deleteShop, setBuyShop, setSellShop, setShopBalance } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setForceFieldName, deleteForceFieldMetadata, setForceFieldApprovals, deleteForceFieldApprovals, setFFApprovedPlayers, pushFFApprovedPlayer, popFFApprovedPlayer, updateFFApprovedPlayer, setFFApprovedNFT, pushFFApprovedNFT, popFFApprovedNFT, updateFFApprovedNFT } from "@biomesaw/experience/src/utils/ChipUtils.sol";

import { Metadata } from "./codegen/tables/Metadata.sol";
import { Shop, ShopData } from "@biomesaw/experience/src/codegen/tables/Shop.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";

contract Chip is IChip, Ownable {
  constructor(address _biomeWorldAddress) Ownable(msg.sender) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.Chest,
        name: "Buy Blocks",
        description: "Send Ether to players for placing blocks in your chest."
      })
    );
  }

  function doWithdraw(address player, bytes32 chestEntityId, uint256 amount) internal {
    require(amount > 0, "Amount must be greater than 0");
    uint256 currentBalance = Shop.getBalance(chestEntityId);
    require(currentBalance >= amount, "Insufficient balance");
    uint256 newBalance = currentBalance - amount;
    setShopBalance(chestEntityId, newBalance);

    (bool sent, ) = player.call{ value: amount }("");
    require(sent, "Failed to send Ether");
  }

  function setupBuyShop(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 buyPrice) public payable {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can set up the shop");
    require(Shop.getBuyObjectTypeId(chestEntityId) == NullObjectTypeId, "Chest already has a shop");

    setBuyShop(chestEntityId, buyObjectTypeId, buyPrice);
    uint256 newBalance = Shop.getBalance(chestEntityId) + msg.value;
    setShopBalance(chestEntityId, newBalance);
  }

  function changeBuyPrice(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 newPrice) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can change the price");
    require(Shop.getBuyObjectTypeId(chestEntityId) == buyObjectTypeId, "Chest is not set up");

    setBuyShop(chestEntityId, buyObjectTypeId, newPrice);
  }

  function refillBuyShopBalance(bytes32 chestEntityId, uint8 buyObjectTypeId) public payable {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can refill the chest");
    require(Shop.getBuyObjectTypeId(chestEntityId) == buyObjectTypeId, "Chest is not set up");

    uint256 newBalance = Shop.getBalance(chestEntityId) + msg.value;
    setShopBalance(chestEntityId, newBalance);
  }

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can withdraw the balance");
    doWithdraw(msg.sender, chestEntityId, amount);
  }

  function destroyBuyShop(bytes32 chestEntityId, uint8 buyObjectTypeId) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can destroy the chest");
    require(Shop.getBuyObjectTypeId(chestEntityId) == buyObjectTypeId, "Chest is not set up");

    uint256 currentBalance = Shop.getBalance(chestEntityId);
    if (currentBalance > 0) {
      doWithdraw(msg.sender, chestEntityId, currentBalance);
    }

    deleteShop(chestEntityId);
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IChip).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function onAttached(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {
    address owner = getPlayerFromEntity(playerEntityId);
    setChipAttacher(entityId, owner);
  }

  function onDetached(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {
    address previousOwner = ChipAttachment.getAttacher(entityId);
    uint256 currentBalance = Shop.getBalance(entityId);
    if (currentBalance > 0) {
      doWithdraw(previousOwner, entityId, currentBalance);
    }

    deleteChipAttacher(entityId);
    if (
      Shop.getBuyObjectTypeId(entityId) != NullObjectTypeId || Shop.getSellObjectTypeId(entityId) != NullObjectTypeId
    ) {
      // Clear existing shop data
      deleteShop(entityId);
    }
  }

  function withdrawFees() public onlyOwner {
    uint256 withdrawAmount = Metadata.getTotalFees();
    Metadata.setTotalFees(0);
    (bool sent, ) = owner().call{ value: withdrawAmount }("");
    require(sent, "Failed to send Ether");
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
    address owner = ChipAttachment.getAttacher(chestEntityId);
    require(owner != address(0), "Chest does not exist");
    address player = getPlayerFromEntity(isDeposit ? srcEntityId : dstEntityId);
    if (player == owner) {
      return true;
    }
    if (!isDeposit) {
      return false;
    }

    ShopData memory chestShopData = Shop.get(chestEntityId);
    if (chestShopData.buyObjectTypeId != transferObjectTypeId) {
      return false;
    }
    if (toolEntityId != bytes32(0)) {
      require(
        getNumUsesLeft(toolEntityId) == getDurability(chestShopData.buyObjectTypeId),
        "Tool must have full durability"
      );
    }

    uint256 buyPrice = chestShopData.buyPrice;
    if (buyPrice == 0) {
      return true;
    }

    uint256 amountToPay = numToTransfer * buyPrice;
    uint256 fee = (amountToPay * 1) / 100; // 1% fee

    // Check if there is enough balance in the chest
    uint256 balance = chestShopData.balance;
    require(balance >= amountToPay + fee, "Insufficient balance in chest");

    uint256 newBalance = balance - (amountToPay + fee);
    setShopBalance(chestEntityId, newBalance);
    Metadata.setTotalFees(Metadata.getTotalFees() + fee);

    (bool sent, ) = player.call{ value: amountToPay }("");
    require(sent, "Failed to send Ether");

    return true;
  }

  function onBuild(
    bytes32 forceFieldEntityId,
    bytes32 playerEntityId,
    uint8 objectTypeId,
    VoxelCoord memory coord,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {}

  function onMine(
    bytes32 forceFieldEntityId,
    bytes32 playerEntityId,
    uint8 objectTypeId,
    VoxelCoord memory coord,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {}
}
