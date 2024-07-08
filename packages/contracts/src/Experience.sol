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

import { Players } from "@biomesaw/experience/src/codegen/tables/Players.sol";
import { ExperienceLib } from "./lib/ExperienceLib.sol";
import { PlayerMetadata, PlayerMetadataData } from "./codegen/tables/PlayerMetadata.sol";

contract Experience is IOptionalSystemHook {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initExperience();
  }

  function initExperience() internal {
    setStatus(
      "If anyone kills your player, they will get this eth. If you kill other players, you will get their eth."
    );
    setRegisterMsg(
      "You can't logoff until you withdraw your ether or die. Whenever you hit another player, check if they died in order to earn their ether."
    );
    setUnregisterMsg("You will be unregistered and any remaining balance will be sent to you/your last hitter.");

    bytes32[] memory hookSystemIds = new bytes32[](3);
    hookSystemIds[0] = ResourceId.unwrap(getSystemId("LogoffSystem"));
    hookSystemIds[1] = ResourceId.unwrap(getSystemId("SpawnSystem"));
    hookSystemIds[2] = ResourceId.unwrap(getSystemId("HitSystem"));

    setExperienceMetadata(
      ExperienceMetadataData({
        shouldDelegate: address(0),
        hookSystemIds: hookSystemIds,
        joinFee: 350000000000000,
        name: "Bounty Hunter",
        description: "Kill players to get their ether. Stay alive to keep it."
      })
    );
  }

  function joinExperience() public payable {
    ExperienceLib.ensureJoinRequirements();

    address player = msg.sender;
    require(getEntityFromPlayer(player) != bytes32(0), "You Must First Spawn An Avatar In Biome-1 To Play The Game.");
    require(!PlayerMetadata.getIsRegistered(player), "Player is already registered");
    pushPlayers(player);
    PlayerMetadata.set(
      player,
      PlayerMetadataData({
        balance: msg.value,
        lastWithdrawalTime: block.timestamp,
        lastHitter: address(0),
        isRegistered: true
      })
    );

    setNotification(address(0), string.concat("Player ", Strings.toHexString(player), " has joined the game"));
  }

  function withdraw() public {
    address player = msg.sender;
    require(PlayerMetadata.getIsRegistered(player), "You are not a registered player.");
    require(PlayerMetadata.getLastWithdrawalTime(player) + 2 hours < block.timestamp, "Can't withdraw yet.");

    uint256 balance = PlayerMetadata.getBalance(player);
    require(balance > 0, "Your balance is zero.");

    PlayerMetadata.setLastWithdrawalTime(player, block.timestamp);
    PlayerMetadata.setBalance(player, 0);
    PlayerMetadata.setLastHitter(player, address(0));

    (bool sent, ) = player.call{ value: balance }("");
    require(sent, "Failed to send Ether");
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IOptionalSystemHook).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function transferRemainingBalance(address player, uint256 balance, address recipient) internal {
    if (balance > 0) {
      if (recipient == address(0) || !PlayerMetadata.getIsRegistered(recipient)) {
        (bool sent, ) = player.call{ value: balance }("");
        require(sent, "Failed to send Ether");
      } else {
        PlayerMetadata.setBalance(recipient, PlayerMetadata.getBalance(recipient) + balance);
      }
    }
  }

  function onRegisterHook(
    address msgSender,
    ResourceId systemId,
    uint8 enabledHooksBitmap,
    bytes32 callDataHash
  ) public override onlyBiomeWorld {}

  function removePlayer(address player) internal {
    PlayerMetadata.deleteRecord(player);

    address[] memory players = Players.get(address(this));
    address[] memory newPlayers = new address[](players.length - 1);
    uint256 newPlayersCount = 0;
    for (uint256 i = 0; i < players.length; i++) {
      if (players[i] != player) {
        newPlayers[newPlayersCount] = players[i];
        newPlayersCount++;
      }
    }
    setPlayers(newPlayers);
  }

  function onUnregisterHook(
    address msgSender,
    ResourceId systemId,
    uint8 enabledHooksBitmap,
    bytes32 callDataHash
  ) public override onlyBiomeWorld {
    if (!PlayerMetadata.getIsRegistered(msgSender)) {
      return;
    }

    uint256 balance = PlayerMetadata.getBalance(msgSender);
    address recipient = PlayerMetadata.getLastHitter(msgSender);
    uint256 lastWithdrawalTime = PlayerMetadata.getLastWithdrawalTime(msgSender);
    removePlayer(msgSender);

    if (lastWithdrawalTime + 2 hours < block.timestamp) {
      (bool sent, ) = msgSender.call{ value: balance }("");
      require(sent, "Failed to send Ether");
    } else {
      transferRemainingBalance(msgSender, balance, recipient);
    }
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
    if (!PlayerMetadata.getIsRegistered(msgSender)) {
      return;
    }

    if (isSystemId(systemId, "LogoffSystem")) {
      require(false, "Cannot logoff when registered.");
      return;
    } else if (isSystemId(systemId, "SpawnSystem")) {
      uint256 playerBalance = PlayerMetadata.getBalance(msgSender);
      if (playerBalance == 0) {
        return;
      }
      address recipient = PlayerMetadata.getLastHitter(msgSender);

      removePlayer(msgSender);
      transferRemainingBalance(msgSender, playerBalance, recipient);
    } else if (isSystemId(systemId, "HitSystem")) {
      address hitPlayer = getHitArgs(callData);

      if (PlayerMetadata.getIsRegistered(hitPlayer)) {
        PlayerMetadata.setLastHitter(hitPlayer, msgSender);

        if (getEntityFromPlayer(hitPlayer) == bytes32(0)) {
          PlayerMetadata.setBalance(
            msgSender,
            PlayerMetadata.getBalance(msgSender) + PlayerMetadata.getBalance(hitPlayer)
          );
          removePlayer(hitPlayer);

          setNotification(
            address(0),
            string.concat(
              "Player ",
              Strings.toHexString(hitPlayer),
              " has been killed by ",
              Strings.toHexString(msgSender)
            )
          );
        }
      }
    }
  }

  function getBiomeWorldAddress() public view returns (address) {
    return WorldContextConsumerLib._world();
  }
}
