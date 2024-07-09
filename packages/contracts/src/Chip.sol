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
        name: "Sell Blocks",
        description: "Let players take blocks from your chest by sending you Ether."
      })
    );
  }

  function setupSellShop(bytes32 chestEntityId, uint8 sellObjectTypeId, uint256 sellPrice) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can set up the shop");

    setSellShop(chestEntityId, sellObjectTypeId, sellPrice);
  }

  function destroySellShop(bytes32 chestEntityId, uint8 sellObjectTypeId) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can destroy the shop");

    deleteShop(chestEntityId);
  }

  function withdrawFees() public onlyOwner {
    (bool sent, ) = owner().call{ value: address(this).balance }("");
    require(sent, "Failed to send Ether");
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IChip).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function onAttached(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {
    setChipAttacher(entityId, getPlayerFromEntity(playerEntityId));
  }

  function onDetached(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {
    deleteChipAttacher(entityId);
    if (
      Shop.getBuyObjectTypeId(entityId) != NullObjectTypeId || Shop.getSellObjectTypeId(entityId) != NullObjectTypeId
    ) {
      deleteShop(entityId);
    }
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
    if (isDeposit) {
      return false;
    }
    ShopData memory chestShopData = Shop.get(chestEntityId);
    if (chestShopData.sellObjectTypeId != transferObjectTypeId) {
      return false;
    }
    if (toolEntityId != bytes32(0)) {
      require(
        getNumUsesLeft(toolEntityId) == getDurability(chestShopData.sellObjectTypeId),
        "Tool must have full durability"
      );
    }

    uint256 sellPrice = chestShopData.sellPrice;
    if (sellPrice == 0) {
      return true;
    }

    uint256 amountToCharge = sellPrice * numToTransfer;
    uint256 fee = (amountToCharge * 1) / 100; // 1% fee
    require(msg.value >= amountToCharge + fee, "Insufficient Ether sent");

    (bool sent, ) = owner.call{ value: amountToCharge }("");
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
