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

contract Experience is ICustomUnregisterDelegation, IOptionalSystemHook {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initExperience();
  }

  function initExperience() internal {
    setStatus("Will move when you're near it, and move back once you're away from it");
    setRegisterMsg("Only works for whitelisted players");

    bytes32[] memory hookSystemIds = new bytes32[](2);
    hookSystemIds[0] = ResourceId.unwrap(getSystemId("MoveSystem"));
    hookSystemIds[1] = ResourceId.unwrap(getSystemId("HitSystem"));

    setExperienceMetadata(
      ExperienceMetadataData({
        shouldDelegate: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        hookSystemIds: hookSystemIds,
        joinFee: 0,
        name: "Location Guard Service",
        description: "Will move when you're near it, and move back once you're away from it"
      })
    );
  }

  function joinExperience() public payable {
    ExperienceLib.ensureJoinRequirements();
  }

  function addAllowedPlayer(address player) public {
    require(msg.sender == ExperienceMetadata.getShouldDelegate(address(this)), "Only the guard can add players");
    address[] memory allowedPlayers = GameMetadata.getAllowedPlayers();
    for (uint i = 0; i < allowedPlayers.length; i++) {
      require(allowedPlayers[i] != player, "Player already allowed");
    }
    GameMetadata.pushAllowedPlayers(player);
  }

  function setGuardBuild(string memory name, BuildWithPos memory build) public {
    require(
      msg.sender == ExperienceMetadata.getShouldDelegate(address(this)),
      "Only the guard can set the guard build"
    );
    setBuildWithPos(bytes32(uint256(1)), name, build);
  }

  function setGuardPosition(VoxelCoord memory position) public {
    require(
      msg.sender == ExperienceMetadata.getShouldDelegate(address(this)),
      "Only the guard can set the guard position"
    );
    GameMetadata.setGuardPositionX(position.x);
    GameMetadata.setGuardPositionY(position.y);
    GameMetadata.setGuardPositionZ(position.z);
  }

  function setUnguardPosition(VoxelCoord[] memory positions) public {
    require(
      msg.sender == ExperienceMetadata.getShouldDelegate(address(this)),
      "Only the guard can set the guard position"
    );
    int16[] memory unguardPositionsX = new int16[](positions.length);
    int16[] memory unguardPositionsY = new int16[](positions.length);
    int16[] memory unguardPositionsZ = new int16[](positions.length);
    for (uint i = 0; i < positions.length; i++) {
      unguardPositionsX[i] = positions[i].x;
      unguardPositionsY[i] = positions[i].y;
      unguardPositionsZ[i] = positions[i].z;
    }
    GameMetadata.setUnguardPositionsX(unguardPositionsX);
    GameMetadata.setUnguardPositionsY(unguardPositionsY);
    GameMetadata.setUnguardPositionsZ(unguardPositionsZ);
  }

  function hitIntruder(address intruder) public {
    address[] memory allowedPlayers = GameMetadata.getAllowedPlayers();
    for (uint i = 0; i < allowedPlayers.length; i++) {
      require(allowedPlayers[i] != intruder, "Cannot hit allowed players");
    }
    callHit(ExperienceMetadata.getShouldDelegate(address(this)), intruder);
  }

  function getIntruders() public view returns (address[] memory) {
    address guardAddress = ExperienceMetadata.getShouldDelegate(address(this));
    bytes32 guardEntityId = getEntityFromPlayer(guardAddress);
    if (guardEntityId == bytes32(0)) {
      return new address[](0);
    }
    VoxelCoord memory guardCoord = getPosition(guardEntityId);
    // Check all possible locations around the guard
    address[] memory allIntruders = new address[](26);
    address[] memory allowedPlayers = GameMetadata.getAllowedPlayers();
    uint intrudersCount = 0;
    for (int8 dx = -1; dx <= 1; dx++) {
      for (int8 dy = -1; dy <= 1; dy++) {
        for (int8 dz = -1; dz <= 1; dz++) {
          if (dx == 0 && dy == 0 && dz == 0) {
            continue;
          }
          VoxelCoord memory coord = VoxelCoord({ x: guardCoord.x + dx, y: guardCoord.y + dy, z: guardCoord.z + dz });
          address player = getPlayerFromEntity(getEntityAtCoord(coord));
          if (player != address(0)) {
            bool isAllowed = false;
            for (uint i = 0; i < allowedPlayers.length; i++) {
              if (allowedPlayers[i] == player) {
                isAllowed = true;
                break;
              }
            }
            if (!isAllowed) {
              allIntruders[intrudersCount] = player;
              intrudersCount++;
            }
          }
        }
      }
    }
    address[] memory intruders = new address[](intrudersCount);
    for (uint i = 0; i < intrudersCount; i++) {
      intruders[i] = allIntruders[i];
    }

    return intruders;
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
      return GameMetadata.lengthAllowedPlayers() == 0;
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
    VoxelCoord memory guardPosition = VoxelCoord({
      x: GameMetadata.getGuardPositionX(),
      y: GameMetadata.getGuardPositionY(),
      z: GameMetadata.getGuardPositionZ()
    });

    address guardAddress = ExperienceMetadata.getShouldDelegate(address(this));
    address[] memory allowedPlayers = GameMetadata.getAllowedPlayers();
    bool isAllowed = false;
    for (uint i = 0; i < allowedPlayers.length; i++) {
      if (allowedPlayers[i] == msgSender) {
        isAllowed = true;
        break;
      }
    }

    if (isSystemId(systemId, "MoveSystem")) {
      if (msgSender == guardAddress) {
        return;
      }

      bytes32 guardEntityId = getEntityFromPlayer(guardAddress);
      if (guardEntityId == bytes32(0)) {
        return;
      }

      VoxelCoord[] memory unGuardPositions;
      {
        int16[] memory unGuardPositionsX = GameMetadata.getUnguardPositionsX();
        int16[] memory unGuardPositionsY = GameMetadata.getUnguardPositionsY();
        int16[] memory unGuardPositionsZ = GameMetadata.getUnguardPositionsZ();
        unGuardPositions = new VoxelCoord[](unGuardPositionsX.length);
        for (uint i = 0; i < unGuardPositions.length; i++) {
          unGuardPositions[i] = VoxelCoord({
            x: unGuardPositionsX[i],
            y: unGuardPositionsY[i],
            z: unGuardPositionsZ[i]
          });
        }
      }

      // check if player is beside the guard
      VoxelCoord memory playerCoord = getPosition(getEntityFromPlayer(msgSender));
      VoxelCoord memory guardCoord = getPosition(getEntityFromPlayer(guardAddress));
      if (voxelCoordsAreEqual(guardCoord, guardPosition)) {
        if (inSurroundingCube(playerCoord, 1, guardCoord)) {
          if (!isAllowed) {
            return;
          }

          // Move the guard away from its guarding position
          callMove(guardAddress, unGuardPositions);
          setNotification(msgSender, "Guard has moved away from its guarding position");
        }
      } else {
        // move guard back to its guarding position
        VoxelCoord[] memory newCoords = new VoxelCoord[](unGuardPositions.length);
        for (uint256 i = 0; i < newCoords.length - 1; i++) {
          newCoords[i] = unGuardPositions[i];
        }
        newCoords[unGuardPositions.length - 1] = guardPosition;
        callMove(guardAddress, newCoords);
        setNotification(msgSender, "Guard is back at its guarding position");
      }
    } else if (isSystemId(systemId, "HitSystem")) {
      address hitAddress = getHitArgs(callData);
      if (msgSender == guardAddress) {
        bool isHitAllowed = false;
        for (uint i = 0; i < allowedPlayers.length; i++) {
          if (allowedPlayers[i] == hitAddress) {
            isHitAllowed = true;
            break;
          }
        }
        require(!isHitAllowed, "Guard cannot hit allowed players");
      } else {
        require(hitAddress != guardAddress, "Players cannot hit the guard");
      }
    }
  }

  function getBiomeWorldAddress() public view returns (address) {
    return WorldContextConsumerLib._world();
  }
}
