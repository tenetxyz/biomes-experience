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
import { Builds } from "@biomesaw/experience/src/codegen/tables/Builds.sol";
import { LOGO_BUILD_ID } from "./Constants.sol";
import { GameMetadata } from "./codegen/tables/GameMetadata.sol";
import { Builder } from "./codegen/tables/Builder.sol";

contract Experience is ICustomUnregisterDelegation, IOptionalSystemHook {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initExperience();
  }

  function initExperience() internal {
    setStatus("Build and submit to be allowed drops");
    setRegisterMsg("Build hook tracks who placed down a block");

    bytes32[] memory hookSystemIds = new bytes32[](1);
    hookSystemIds[0] = ResourceId.unwrap(getSystemId("BuildSystem"));

    setExperienceMetadata(
      ExperienceMetadataData({
        shouldDelegate: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        hookSystemIds: hookSystemIds,
        joinFee: 0,
        name: "Build For Drops",
        description: "Submit builds and drop items!"
      })
    );
  }

  function joinExperience() public payable {
    ExperienceLib.ensureJoinRequirements();
  }

  function setBuildForDrops(string memory name, Build memory build) public {
    require(msg.sender == ExperienceMetadata.getShouldDelegate(address(this)), "Only delegator can add build");
    require(build.objectTypeIds.length > 0, "Must specify at least one object type ID");
    require(
      build.objectTypeIds.length == build.relativePositions.length,
      "Number of object type IDs must match number of relative positions"
    );
    require(
      voxelCoordsAreEqual(build.relativePositions[0], VoxelCoord({ x: 0, y: 0, z: 0 })),
      "First relative position must be (0, 0, 0)"
    );
    require(Builds.lengthObjectTypeIds(address(this), LOGO_BUILD_ID) == 0, "Logo build already exists");

    setBuild(LOGO_BUILD_ID, name, build);
  }

  function matchBuild(VoxelCoord memory baseWorldCoord) public {
    Build memory build = getBuild(address(this), LOGO_BUILD_ID);
    require(build.objectTypeIds.length > 0, "Logo build not set");

    address msgSender = msg.sender;

    // Go through each relative position, aplpy it to the base world coord, and check if the object type id matches
    for (uint256 i = 0; i < build.objectTypeIds.length; i++) {
      VoxelCoord memory absolutePosition = VoxelCoord({
        x: baseWorldCoord.x + build.relativePositions[i].x,
        y: baseWorldCoord.y + build.relativePositions[i].y,
        z: baseWorldCoord.z + build.relativePositions[i].z
      });
      bytes32 entityId = getEntityAtCoord(absolutePosition);

      uint8 objectTypeId;
      if (entityId == bytes32(0)) {
        // then it's the terrain
        objectTypeId = getTerrainBlock(absolutePosition);
      } else {
        objectTypeId = getObjectType(entityId);

        address builder = Builder.get(absolutePosition.x, absolutePosition.y, absolutePosition.z);
        require(builder == msgSender, "Builder does not match");
      }
      if (objectTypeId != build.objectTypeIds[i]) {
        revert("Build does not match");
      }
    }

    // Add user to allowed item drops, if not already added
    bool isAllowed = false;
    address[] memory allowedItemDrops = GameMetadata.getAllowedDrops();
    for (uint i = 0; i < allowedItemDrops.length; i++) {
      if (allowedItemDrops[i] == msgSender) {
        isAllowed = true;
        break;
      }
    }
    require(!isAllowed, "Already allowed to drop items");
    GameMetadata.pushAllowedDrops(msgSender);

    setNotification(
      ExperienceMetadata.getShouldDelegate(address(this)),
      "A new player has been added to allowed item drops"
    );
  }

  function dropItem(bytes32 toolEntityId) public {
    bool isAllowed = false;
    address delegatorAddress = ExperienceMetadata.getShouldDelegate(address(this));
    address[] memory allowedItemDrops = GameMetadata.getAllowedDrops();
    require(allowedItemDrops.length > 0, "No allowed item drops");
    address[] memory newAllowedItemDrops = new address[](allowedItemDrops.length - 1);
    uint256 newAllowedItemDropsIndex = 0;
    for (uint i = 0; i < allowedItemDrops.length; i++) {
      if (allowedItemDrops[i] == msg.sender) {
        isAllowed = true;
      } else {
        newAllowedItemDrops[newAllowedItemDropsIndex] = allowedItemDrops[i];
        newAllowedItemDropsIndex++;
      }
    }
    require(isAllowed, "Not allowed to drop items");
    GameMetadata.setAllowedDrops(newAllowedItemDrops);

    bytes32 playerEntityId = getEntityFromPlayer(delegatorAddress);
    require(playerEntityId != bytes32(0), "Player entity not found");
    VoxelCoord memory dropCoord = getEmptyBlockOnGround(getPosition(playerEntityId));

    callDrop(delegatorAddress, getObjectType(toolEntityId), 1, dropCoord, toolEntityId);

    setNotification(delegatorAddress, "Item dropped");
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
      return GameMetadata.lengthAllowedDrops() == 0;
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
    if (isSystemId(systemId, "BuildSystem")) {
      (, VoxelCoord memory coord) = getBuildArgs(callData);
      Builder.set(coord.x, coord.y, coord.z, msgSender);
    }
  }

  function getBiomeWorldAddress() public view returns (address) {
    return WorldContextConsumerLib._world();
  }
}
