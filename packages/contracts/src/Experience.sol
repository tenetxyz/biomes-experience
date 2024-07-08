// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

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

import { IWorld } from "@biomesaw/world/src/codegen/world/IWorld.sol";
import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { voxelCoordsAreEqual, inSurroundingCube } from "@biomesaw/utils/src/VoxelCoordUtils.sol";
import { IWorld as IExperienceWorld } from "@biomesaw/experience/src/codegen/world/IWorld.sol";
import { ExperienceMetadata, ExperienceMetadataData } from "@biomesaw/experience/src/codegen/tables/ExperienceMetadata.sol";

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

import { ExperienceLib } from "./lib/ExperienceLib.sol";
import { GameMetadata } from "./codegen/tables/GameMetadata.sol";
import { VaultTools } from "./codegen/tables/VaultTools.sol";
import { VaultObjects } from "./codegen/tables/VaultObjects.sol";

contract Experience is ICustomUnregisterDelegation, IOptionalSystemHook {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initExperience();
  }

  function initExperience() internal {
    setStatus("Transfer your items for safe-guarding by the chest");
    setRegisterMsg("Transfer your items for safe-guarding by the guard");

    bytes32[] memory hookSystemIds = new bytes32[](1);
    hookSystemIds[0] = ResourceId.unwrap(getSystemId("TransferSystem"));

    setExperienceMetadata(
      ExperienceMetadataData({
        shouldDelegate: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        hookSystemIds: hookSystemIds,
        joinFee: 0,
        name: "Vault Guard Service",
        description: "Transfer your items for safe-guarding by the guard"
      })
    );
  }

  function joinExperience() public payable {
    ExperienceLib.ensureJoinRequirements();
  }

  function setVaultChestCoord(VoxelCoord memory vaultChestCoord) public {
    require(
      msg.sender == ExperienceMetadata.getShouldDelegate(address(this)),
      "Only the guard can set the vault chest coord"
    );
    GameMetadata.setVaultChestCoordX(vaultChestCoord.x);
    GameMetadata.setVaultChestCoordY(vaultChestCoord.y);
    GameMetadata.setVaultChestCoordZ(vaultChestCoord.z);
  }

  function withdraw(uint8 objectTypeId, uint16 numToWithdraw, bytes32 withdrawChestEntityId) public {
    address guardAddress = ExperienceMetadata.getShouldDelegate(address(this));
    require(withdrawChestEntityId != bytes32(0), "The withdrawal chest is missing");
    bytes32 vaultChestEntityId = getEntityAtCoord(
      VoxelCoord({
        x: GameMetadata.getVaultChestCoordX(),
        y: GameMetadata.getVaultChestCoordY(),
        z: GameMetadata.getVaultChestCoordZ()
      })
    );
    require(vaultChestEntityId != bytes32(0), "The vault chest is missing");
    bytes32 guardEntityId = getEntityFromPlayer(guardAddress);
    require(guardEntityId != bytes32(0), "The guard is missing");
    require(
      inSurroundingCube(getPosition(withdrawChestEntityId), 1, getPosition(guardEntityId)),
      "The withdrawal chest is not beside the guard"
    );
    require(!isTool(objectTypeId), "Use the withdrawTool function to withdraw tools");

    // Check if the player owns the items in the vault chest
    address player = msg.sender;
    uint16 playerObjectCount = VaultObjects.get(player, objectTypeId);
    require(playerObjectCount >= numToWithdraw, "You don't have enough items in the vault chest");
    // Update the vault chest object counts
    VaultObjects.set(player, objectTypeId, playerObjectCount - numToWithdraw);

    // Transfer the items to the guard
    callTransfer(guardAddress, vaultChestEntityId, guardEntityId, objectTypeId, numToWithdraw, bytes32(0));

    // Then, transfer the items to the withdrawal chest
    callTransfer(guardAddress, guardEntityId, withdrawChestEntityId, objectTypeId, numToWithdraw, bytes32(0));
  }

  function withdrawTool(bytes32 toolEntityId, bytes32 withdrawChestEntityId) public {
    address guardAddress = ExperienceMetadata.getShouldDelegate(address(this));
    require(withdrawChestEntityId != bytes32(0), "The withdrawal chest is missing");
    bytes32 vaultChestEntityId = getEntityAtCoord(
      VoxelCoord({
        x: GameMetadata.getVaultChestCoordX(),
        y: GameMetadata.getVaultChestCoordY(),
        z: GameMetadata.getVaultChestCoordZ()
      })
    );
    require(withdrawChestEntityId != bytes32(0), "The vault chest is missing");
    bytes32 guardEntityId = getEntityFromPlayer(guardAddress);
    require(guardEntityId != bytes32(0), "The guard is missing");
    require(
      inSurroundingCube(getPosition(guardEntityId), 1, getPosition(withdrawChestEntityId)),
      "The withdrawal chest is not beside the guard"
    );

    uint8 objectTypeId = getObjectType(toolEntityId);
    require(objectTypeId != uint8(0), "The tool is missing");
    require(isTool(objectTypeId), "The entity is not a tool");
    uint16 numToWithdraw = 1;

    // Check if the player owns the items in the vault chest
    {
      address player = msg.sender;
      uint16 playerObjectCount = VaultObjects.get(player, objectTypeId);
      require(playerObjectCount >= numToWithdraw, "You don't have enough items in the vault chest");
      require(VaultTools.getOwner(toolEntityId) == player, "You don't own the tool");
      // Update the vault chest object counts
      VaultObjects.set(player, objectTypeId, playerObjectCount - numToWithdraw);
      VaultTools.deleteRecord(toolEntityId);
    }

    // Transfer the items to the guard
    callTransfer(guardAddress, vaultChestEntityId, guardEntityId, objectTypeId, numToWithdraw, toolEntityId);

    // Then, transfer the items to the withdrawal chest
    callTransfer(guardAddress, guardEntityId, withdrawChestEntityId, objectTypeId, numToWithdraw, toolEntityId);
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return
      interfaceId == type(ICustomUnregisterDelegation).interfaceId ||
      interfaceId == type(IOptionalSystemHook).interfaceId ||
      interfaceId == type(IERC165).interfaceId;
  }

  function canUnregister(address delegator) public override onlyBiomeWorld returns (bool) {
    if (delegator == ExperienceMetadata.getShouldDelegate(address(this))) {
      VoxelCoord memory vaultChestCoord = VoxelCoord({
        x: GameMetadata.getVaultChestCoordX(),
        y: GameMetadata.getVaultChestCoordY(),
        z: GameMetadata.getVaultChestCoordZ()
      });
      bytes32 vaultChestEntityId = getEntityAtCoord(vaultChestCoord);
      if (vaultChestEntityId != bytes32(0) && getNumSlotsUsed(vaultChestEntityId) > 0) {
        return false;
      }
    }

    return true;
  }

  function onRegisterHook(
    address msgSender,
    ResourceId systemId,
    uint8 enabledHooksBitmap,
    bytes32 callDataHash
  ) public override onlyBiomeWorld {}

  function onUnregisterHook(
    address msgSender,
    ResourceId systemId,
    uint8 enabledHooksBitmap,
    bytes32 callDataHash
  ) public override onlyBiomeWorld {}

  function onBeforeCallSystem(
    address msgSender,
    ResourceId systemId,
    bytes memory callData
  ) public override onlyBiomeWorld {}

  function onAfterCallSystem(
    address msgSender,
    ResourceId systemId,
    bytes memory callData
  ) public override onlyBiomeWorld {
    if (!isSystemId(systemId, "TransferSystem")) {
      return;
    }

    address guardAddress = ExperienceMetadata.getShouldDelegate(address(this));
    if (msgSender == guardAddress) {
      return;
    }

    bytes32 vaultChestEntityId = getEntityAtCoord(
      VoxelCoord({
        x: GameMetadata.getVaultChestCoordX(),
        y: GameMetadata.getVaultChestCoordY(),
        z: GameMetadata.getVaultChestCoordZ()
      })
    );
    (
      bytes32 srcEntityId,
      bytes32 dstEntityId,
      uint8 transferObjectTypeId,
      uint16 numToTransfer,
      bytes32 toolEntityId
    ) = getTransferArgs(callData);
    // Check if dstEntityId is a chest that is beside the guard
    require(srcEntityId != vaultChestEntityId, "You can't transfer from the vault chest");
    require(dstEntityId != vaultChestEntityId, "You can't transfer to the vault chest");
    if (getObjectType(dstEntityId) != ChestObjectID) {
      return;
    }
    bytes32 guardEntityId = getEntityFromPlayer(guardAddress);
    if (guardEntityId == bytes32(0)) {
      return;
    }

    {
      VoxelCoord memory guardCoord = getPosition(guardEntityId);
      VoxelCoord memory dstCoord = getPosition(dstEntityId);
      if (!inSurroundingCube(dstCoord, 1, guardCoord)) {
        return;
      }
    }

    if (vaultChestEntityId == bytes32(0)) {
      setNotification(msgSender, "The vault chest is missing");
      return;
    }

    // Update the vault chest tool owners and object counts
    if (toolEntityId != bytes32(0)) {
      VaultTools.setOwner(toolEntityId, msgSender);
    }

    VaultObjects.set(
      msgSender,
      transferObjectTypeId,
      VaultObjects.get(msgSender, transferObjectTypeId) + numToTransfer
    );
    setNotification(msgSender, "Items transferred to the vault chest");

    // Note: we don't check if the inventory of the guard or chest is full here
    // as the transfer call will fail if the inventory is full

    // Transfer the items to the guard
    callTransfer(guardAddress, dstEntityId, guardEntityId, transferObjectTypeId, numToTransfer, toolEntityId);

    // Then, transfer the items to the vault chest
    callTransfer(guardAddress, guardEntityId, vaultChestEntityId, transferObjectTypeId, numToTransfer, toolEntityId);
  }

  function getBiomeWorldAddress() public view returns (address) {
    return WorldContextConsumerLib._world();
  }
}
