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

import { Countdown } from "@biomesaw/experience/src/codegen/tables/Countdown.sol";
import { DEATHMATCH_AREA_ID } from "./Constants.sol";
import { ExperienceLib } from "./lib/ExperienceLib.sol";
import { GameMetadata } from "./codegen/tables/GameMetadata.sol";
import { PlayerMetadata, PlayerMetadataData } from "./codegen/tables/PlayerMetadata.sol";
import { hasValidInventory, updatePlayersToDisplay, disqualifyPlayer } from "./Utils.sol";

contract Experience is IOptionalSystemHook {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initExperience();
  }

  function initExperience() internal {
    setStatus("Waiting for the game to start");
    setRegisterMsg(
      "Move hook, hit hook, and logoff hook prevent the player from moving outside match area, hitting players before match starts, or logging off during the match. Mine hook tracks kills from gravity."
    );
    setUnregisterMsg("You will be disqualified if you unregister");

    bytes32[] memory hookSystemIds = new bytes32[](4);
    hookSystemIds[0] = ResourceId.unwrap(getSystemId("MoveSystem"));
    hookSystemIds[1] = ResourceId.unwrap(getSystemId("HitSystem"));
    hookSystemIds[2] = ResourceId.unwrap(getSystemId("LogoffSystem"));
    hookSystemIds[3] = ResourceId.unwrap(getSystemId("MineSystem"));

    setExperienceMetadata(
      ExperienceMetadataData({
        shouldDelegate: address(0),
        hookSystemIds: hookSystemIds,
        joinFee: 1400000000000000,
        name: "Deathmatch",
        description: "Stay inside the match area and kill as many players as you can! Most kills after 30 minutes gets reward pool."
      })
    );
  }

  function joinExperience() public payable {
    ExperienceLib.ensureJoinRequirements();

    address player = msg.sender;
    require(!GameMetadata.getIsGameStarted(), "Game has already started.");
    bytes32 playerEntityId = getEntityFromPlayer(player);
    require(playerEntityId != bytes32(0), "You Must First Spawn An Avatar In Biome-1 To Play The Game");
    require(hasValidInventory(playerEntityId), "You can only have a maximum of 3 tools and 20 blocks");

    require(!PlayerMetadata.getIsRegistered(player), "Player is already registered");
    PlayerMetadata.setIsRegistered(player, true);
    PlayerMetadata.setIsAlive(player, true);
    GameMetadata.pushPlayers(player);
    updatePlayersToDisplay();

    setNotification(address(0), string.concat("Player ", Strings.toHexString(player), " has joined the game"));
  }

  function startGame(uint256 numBlocksToEnd) public {
    require(msg.sender == GameMetadata.getGameStarter(), "Only the game starter can start the game.");
    require(!GameMetadata.getIsGameStarted(), "Game has already started.");

    address[] memory registeredPlayers = GameMetadata.getPlayers();

    Area memory matchArea = getArea(address(this), DEATHMATCH_AREA_ID);

    GameMetadata.setIsGameStarted(true);
    setCountdownEndBlock(block.number + numBlocksToEnd);
    setNotification(address(0), "Game has started!");

    for (uint i = 0; i < registeredPlayers.length; i++) {
      bytes32 playerEntity = getEntityFromPlayer(registeredPlayers[i]);
      VoxelCoord memory playerPosition = getPosition(playerEntity);
      if (
        playerEntity == bytes32(0) ||
        getIsLoggedOff(playerEntity) ||
        !insideAreaIgnoreY(matchArea, playerPosition) ||
        !hasValidInventory(playerEntity)
      ) {
        disqualifyPlayer(registeredPlayers[i]);
      }

      updatePlayersToDisplay();
    }

    setStatus("Game is in progress.");
  }

  function setMatchArea(string memory name, Area memory area) public {
    require(msg.sender == GameMetadata.getGameStarter(), "Only the game starter can set the match area.");
    require(!GameMetadata.getIsGameStarted(), "Game has already started.");
    setArea(DEATHMATCH_AREA_ID, name, area);
  }

  function setDeathmatchJoinFee(uint256 newJoinFee) public {
    require(msg.sender == GameMetadata.getGameStarter(), "Only the game starter can set the join fee.");
    require(!GameMetadata.getIsGameStarted(), "Game has already started.");

    setJoinFee(newJoinFee);
  }

  function claimRewardPool() public {
    require(GameMetadata.getIsGameStarted(), "Game has not started yet.");
    require(block.number > Countdown.getCountdownEndBlock(address(this)), "Game has not ended yet.");
    address[] memory registeredPlayers = GameMetadata.getPlayers();
    if (registeredPlayers.length == 0) {
      resetGame(registeredPlayers);
      return;
    }

    uint256 maxKills = 0;
    for (uint i = 0; i < registeredPlayers.length; i++) {
      if (PlayerMetadata.getIsDisqualified(registeredPlayers[i])) {
        continue;
      }
      uint256 playerKills = PlayerMetadata.getNumKills(registeredPlayers[i]);
      if (playerKills > maxKills) {
        maxKills = playerKills;
      }
    }

    address[] memory playersWithMostKills = new address[](registeredPlayers.length);
    uint256 numPlayersWithMostKills = 0;
    for (uint i = 0; i < registeredPlayers.length; i++) {
      if (PlayerMetadata.getIsDisqualified(registeredPlayers[i])) {
        continue;
      }
      if (PlayerMetadata.getNumKills(registeredPlayers[i]) == maxKills) {
        playersWithMostKills[numPlayersWithMostKills] = registeredPlayers[i];
        numPlayersWithMostKills++;
      }
    }

    uint256 rewardPool = address(this).balance;
    if (numPlayersWithMostKills == 0 || rewardPool == 0) {
      resetGame(registeredPlayers);
      return;
    }

    // reset the game state
    resetGame(registeredPlayers);

    // Divide the reward pool among the players with the most kills
    uint256 rewardPerPlayer = rewardPool / numPlayersWithMostKills;
    for (uint i = 0; i < playersWithMostKills.length; i++) {
      if (playersWithMostKills[i] == address(0)) {
        continue;
      }

      (bool sent, ) = playersWithMostKills[i].call{ value: rewardPerPlayer }("");
      require(sent, "Failed to send Ether");
    }
  }

  function resetGame(address[] memory registeredPlayers) internal {
    setNotification(address(0), "Game has ended. Reward pool has been distributed.");

    GameMetadata.setIsGameStarted(false);
    setCountdownEndBlock(0);
    for (uint i = 0; i < registeredPlayers.length; i++) {
      PlayerMetadata.deleteRecord(registeredPlayers[i]);
    }
    GameMetadata.setPlayers(new address[](0));
    updatePlayersToDisplay();

    setStatus("Waiting for the game to start");
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
  ) public override onlyBiomeWorld {
    disqualifyPlayer(msgSender);
  }

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
    PlayerMetadataData memory playerMetadata = PlayerMetadata.get(msgSender);
    if (!playerMetadata.isRegistered) {
      return;
    }
    bool isAlive = playerMetadata.isAlive;
    bool isGameStarted = GameMetadata.getIsGameStarted();
    uint256 gameEndBlock = Countdown.getCountdownEndBlock(address(this));
    if (isSystemId(systemId, "LogoffSystem")) {
      require(!isGameStarted || block.number > gameEndBlock, "Cannot logoff during the game");
      return;
    } else if (isSystemId(systemId, "HitSystem")) {
      if (isGameStarted && block.number > gameEndBlock) {
        return;
      }
      if (isGameStarted && isAlive) {
        (uint256 numNewDeadPlayers, bool msgSenderDied) = updateAlivePlayers(msgSender);
        if (msgSenderDied) {
          numNewDeadPlayers -= 1;
        }
        PlayerMetadata.setNumKills(msgSender, PlayerMetadata.getNumKills(msgSender) + numNewDeadPlayers);
      } else {
        address hitPlayer = getHitArgs(callData);
        PlayerMetadataData memory hitPlayerMetadata = PlayerMetadata.get(hitPlayer);
        require(
          !hitPlayerMetadata.isRegistered || !hitPlayerMetadata.isAlive || hitPlayerMetadata.isDisqualified,
          "Cannot hit game players before the game starts or if you died."
        );
      }
    } else if (isSystemId(systemId, "MineSystem")) {
      if (!isGameStarted || !isAlive || block.number > gameEndBlock) {
        return;
      }
      (uint256 numNewDeadPlayers, bool msgSenderDied) = updateAlivePlayers(msgSender);
      if (msgSenderDied) {
        numNewDeadPlayers -= 1;
      }
      PlayerMetadata.setNumKills(msgSender, PlayerMetadata.getNumKills(msgSender) + numNewDeadPlayers);
    } else if (isSystemId(systemId, "MoveSystem")) {
      if (!isGameStarted || block.number > gameEndBlock) {
        return;
      }

      Area memory matchArea = getArea(address(this), DEATHMATCH_AREA_ID);

      VoxelCoord memory playerPosition = getPosition(getEntityFromPlayer(msgSender));
      if (isAlive) {
        require(
          insideAreaIgnoreY(matchArea, playerPosition),
          "Cannot move outside the match area while the game is running"
        );
      } else {
        require(
          !insideAreaIgnoreY(matchArea, playerPosition),
          "Cannot move inside the match area while the game is running and you are dead."
        );
      }
    }
  }

  function updateAlivePlayers(address msgSender) internal returns (uint256, bool) {
    address[] memory registeredPlayers = GameMetadata.getPlayers();
    uint256 numNewDeadPlayers = 0;
    bool msgSenderDied = false;
    for (uint i = 0; i < registeredPlayers.length; i++) {
      address player = registeredPlayers[i];
      if (!PlayerMetadata.getIsAlive(player) || PlayerMetadata.getIsDisqualified(player)) {
        continue;
      }
      bytes32 playerEntity = getEntityFromPlayer(player);
      if (playerEntity == bytes32(0)) {
        numNewDeadPlayers++;
        if (player == msgSender) {
          msgSenderDied = true;
        }
        PlayerMetadata.setIsAlive(player, false);
        setNotification(address(0), string.concat("Player ", Strings.toHexString(player), " has died"));
      }
    }

    if (numNewDeadPlayers > 0) {
      updatePlayersToDisplay();
    }

    return (numNewDeadPlayers, msgSenderDied);
  }

  function getBiomeWorldAddress() public view returns (address) {
    return WorldContextConsumerLib._world();
  }
}
