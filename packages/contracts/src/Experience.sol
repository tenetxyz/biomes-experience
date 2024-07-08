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
import { Builder } from "./codegen/tables/Builder.sol";
import { BuildMetadata, BuildMetadataData } from "./codegen/tables/BuildMetadata.sol";
import { PlayerMetadata } from "./codegen/tables/PlayerMetadata.sol";
import { BuildIds } from "./codegen/tables/BuildIds.sol";

contract Experience is IOptionalSystemHook {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initExperience();
  }

  function initExperience() internal {
    setStatus("Join Monument Chains: Build One Yourself, Reward existing builders, and earn from future builders.");

    bytes32[] memory hookSystemIds = new bytes32[](1);
    hookSystemIds[0] = ResourceId.unwrap(getSystemId("BuildSystem"));

    setExperienceMetadata(
      ExperienceMetadataData({
        shouldDelegate: address(0),
        hookSystemIds: hookSystemIds,
        joinFee: 0,
        name: "Build A Nomics",
        description: "Join Monument Chains: Build One Yourself, Reward existing builders, and earn from future builders."
      })
    );
  }

  function joinExperience() public payable {
    ExperienceLib.ensureJoinRequirements();
  }

  function create(string memory name, uint256 submissionPrice, Build memory blueprint) public {
    require(blueprint.objectTypeIds.length > 0, "Must specify at least one object type ID.");
    require(
      blueprint.objectTypeIds.length == blueprint.relativePositions.length,
      "Number of object type IDs must match number of relative position."
    );
    require(
      voxelCoordsAreEqual(blueprint.relativePositions[0], VoxelCoord({ x: 0, y: 0, z: 0 })),
      "First relative position must be (0, 0, 0)."
    );
    require(bytes(name).length > 0, "Must specify a name.");
    require(submissionPrice > 0, "Must specify a submission price.");

    uint256 newBuildId = BuildIds.get() + 1;
    BuildIds.set(newBuildId);

    BuildMetadata.set(
      bytes32(newBuildId),
      BuildMetadataData({
        submissionPrice: submissionPrice,
        builders: new address[](0),
        locationsX: new int16[](0),
        locationsY: new int16[](0),
        locationsZ: new int16[](0)
      })
    );

    setBuild(bytes32(newBuildId), name, blueprint);

    setNotification(address(0), "A new build has been added to the game.");
  }

  function submitBuilding(uint256 buildingId, VoxelCoord memory baseWorldCoord) public payable {
    require(buildingId <= BuildIds.get(), "Invalid building ID");
    require(bytes(Builds.getName(address(this), bytes32(buildingId))).length > 0, "Invalid building ID");

    Build memory blueprint = getBuild(address(this), bytes32(buildingId));
    BuildMetadataData memory buildMetadata = BuildMetadata.get(bytes32(buildingId));
    require(buildMetadata.submissionPrice > 0, "Build Metadata not found");
    VoxelCoord[] memory existingBuildLocations = new VoxelCoord[](buildMetadata.locationsX.length);
    for (uint i = 0; i < buildMetadata.locationsX.length; i++) {
      existingBuildLocations[i] = VoxelCoord({
        x: buildMetadata.locationsX[i],
        y: buildMetadata.locationsY[i],
        z: buildMetadata.locationsZ[i]
      });
    }

    address msgSender = msg.sender;
    require(msg.value == buildMetadata.submissionPrice, "Incorrect submission price.");

    for (uint i = 0; i < existingBuildLocations.length; ++i) {
      if (voxelCoordsAreEqual(existingBuildLocations[i], baseWorldCoord)) {
        revert("Location already exists");
      }
    }

    // Go through each relative position, apply it to the base world coord, and check if the object type id matches
    for (uint256 i = 0; i < blueprint.objectTypeIds.length; i++) {
      VoxelCoord memory absolutePosition = VoxelCoord({
        x: baseWorldCoord.x + blueprint.relativePositions[i].x,
        y: baseWorldCoord.y + blueprint.relativePositions[i].y,
        z: baseWorldCoord.z + blueprint.relativePositions[i].z
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
      if (objectTypeId != blueprint.objectTypeIds[i]) {
        revert("Build does not match.");
      }
    }

    uint256 numBuilders = buildMetadata.builders.length;
    {
      address[] memory newBuilders = new address[](buildMetadata.builders.length + 1);
      for (uint i = 0; i < buildMetadata.builders.length; i++) {
        newBuilders[i] = buildMetadata.builders[i];
      }
      newBuilders[buildMetadata.builders.length] = msgSender;

      int16[] memory newLocationsX = new int16[](buildMetadata.locationsX.length + 1);
      int16[] memory newLocationsY = new int16[](buildMetadata.locationsY.length + 1);
      int16[] memory newLocationsZ = new int16[](buildMetadata.locationsZ.length + 1);
      for (uint i = 0; i < buildMetadata.locationsX.length; i++) {
        newLocationsX[i] = buildMetadata.locationsX[i];
        newLocationsY[i] = buildMetadata.locationsY[i];
        newLocationsZ[i] = buildMetadata.locationsZ[i];
      }
      newLocationsX[buildMetadata.locationsX.length] = baseWorldCoord.x;
      newLocationsY[buildMetadata.locationsY.length] = baseWorldCoord.y;
      newLocationsZ[buildMetadata.locationsZ.length] = baseWorldCoord.z;

      BuildMetadata.setBuilders(bytes32(buildingId), newBuilders);
      BuildMetadata.setLocationsX(bytes32(buildingId), newLocationsX);
      BuildMetadata.setLocationsY(bytes32(buildingId), newLocationsY);
      BuildMetadata.setLocationsZ(bytes32(buildingId), newLocationsZ);
    }

    if (numBuilders > 0) {
      uint256 splitAmount = msg.value / numBuilders;
      uint256 totalDistributed = splitAmount * numBuilders;
      uint256 remainder = msg.value - totalDistributed;

      for (uint256 i = 0; i < numBuilders; i++) {
        PlayerMetadata.setEarned(
          buildMetadata.builders[i],
          PlayerMetadata.getEarned(buildMetadata.builders[i]) + splitAmount
        );

        setNotification(buildMetadata.builders[i], "You've earned some ether for your contribution to a build.");

        (bool sent, ) = buildMetadata.builders[i].call{ value: splitAmount }("");
        require(sent, "Failed to send Ether");
      }

      if (remainder > 0) {
        (bool sent, ) = msgSender.call{ value: remainder }("");
        require(sent, "Failed to send Ether");
      }
    } else {
      PlayerMetadata.setEarned(msgSender, PlayerMetadata.getEarned(msgSender) + msg.value);

      (bool sent, ) = msgSender.call{ value: msg.value }("");
      require(sent, "Failed to send Ether");
    }
  }

  function challengeBuilding(uint256 buildingId, uint256 n) public {
    require(buildingId <= BuildIds.get(), "Invalid building ID");
    require(bytes(Builds.getName(address(this), bytes32(buildingId))).length > 0, "Invalid building ID");

    Build memory blueprint = getBuild(address(this), bytes32(buildingId));
    BuildMetadataData memory buildMetadata = BuildMetadata.get(bytes32(buildingId));
    require(buildMetadata.submissionPrice > 0, "Build Metadata not found");
    require(n < buildMetadata.locationsX.length, "Invalid index");

    VoxelCoord memory baseWorldCoord = VoxelCoord({
      x: buildMetadata.locationsX[n],
      y: buildMetadata.locationsY[n],
      z: buildMetadata.locationsZ[n]
    });

    bool doesMatch = true;

    // Go through each relative position, apply it to the base world coord, and check if the object type id matches
    for (uint256 i = 0; i < blueprint.objectTypeIds.length; i++) {
      VoxelCoord memory absolutePosition = VoxelCoord({
        x: baseWorldCoord.x + blueprint.relativePositions[i].x,
        y: baseWorldCoord.y + blueprint.relativePositions[i].y,
        z: baseWorldCoord.z + blueprint.relativePositions[i].z
      });
      bytes32 entityId = getEntityAtCoord(absolutePosition);

      uint8 objectTypeId;
      if (entityId == bytes32(0)) {
        // then it's the terrain
        objectTypeId = getTerrainBlock(absolutePosition);
      } else {
        objectTypeId = getObjectType(entityId);
      }
      if (objectTypeId != blueprint.objectTypeIds[i]) {
        doesMatch = false;
        break;
      }
    }

    if (!doesMatch) {
      address[] memory newBuilders = new address[](buildMetadata.builders.length - 1);
      int16[] memory newLocationsX = new int16[](buildMetadata.locationsX.length - 1);
      int16[] memory newLocationsY = new int16[](buildMetadata.locationsY.length - 1);
      int16[] memory newLocationsZ = new int16[](buildMetadata.locationsZ.length - 1);

      for (uint i = 0; i < buildMetadata.builders.length; i++) {
        if (i < n) {
          newBuilders[i] = buildMetadata.builders[i];
          newLocationsX[i] = buildMetadata.locationsX[i];
          newLocationsY[i] = buildMetadata.locationsY[i];
          newLocationsZ[i] = buildMetadata.locationsZ[i];
        } else if (i > n) {
          newBuilders[i - 1] = buildMetadata.builders[i];
          newLocationsX[i - 1] = buildMetadata.locationsX[i];
          newLocationsY[i - 1] = buildMetadata.locationsY[i];
          newLocationsZ[i - 1] = buildMetadata.locationsZ[i];
        }
      }

      BuildMetadata.setBuilders(bytes32(buildingId), newBuilders);
      BuildMetadata.setLocationsX(bytes32(buildingId), newLocationsX);
      BuildMetadata.setLocationsY(bytes32(buildingId), newLocationsY);
      BuildMetadata.setLocationsZ(bytes32(buildingId), newLocationsZ);
    }
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IOptionalSystemHook).interfaceId || interfaceId == type(IERC165).interfaceId;
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
