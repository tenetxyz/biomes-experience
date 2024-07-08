// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { GameMetadata } from "./codegen/tables/GameMetadata.sol";
import { PlayerMetadata, PlayerMetadataData } from "./codegen/tables/PlayerMetadata.sol";

import { getInventoryTool, getInventoryObjects, getCount, isTool } from "@biomesaw/experience/src/utils/EntityUtils.sol";
import { setPlayers, setNotification } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";

function hasValidInventory(bytes32 playerEntityId) view returns (bool) {
  // maximum of 3 tools
  bytes32[] memory playerTools = getInventoryTool(playerEntityId);
  uint8[] memory playerObjects = getInventoryObjects(playerEntityId);

  // maximum of 20 blocks, non-tools
  uint256 numBlocks = 0;
  for (uint i = 0; i < playerObjects.length; i++) {
    if (isTool(playerObjects[i])) continue;
    uint16 count = getCount(playerEntityId, playerObjects[i]);
    numBlocks += count;
  }

  return playerTools.length <= 3 && numBlocks <= 20;
}

function updatePlayersToDisplay() {
  address[] memory registeredPlayers = GameMetadata.getPlayers();
  address[] memory playersToDisplay = new address[](registeredPlayers.length);
  uint256 numPlayersToDisplay = 0;
  for (uint i = 0; i < registeredPlayers.length; i++) {
    address player = registeredPlayers[i];
    if (PlayerMetadata.getIsDisqualified(player) || !PlayerMetadata.getIsAlive(player)) {
      continue;
    }
    playersToDisplay[numPlayersToDisplay] = player;
    numPlayersToDisplay++;
  }
  address[] memory playersToDisplayTrimmed = new address[](numPlayersToDisplay);
  for (uint i = 0; i < numPlayersToDisplay; i++) {
    playersToDisplayTrimmed[i] = playersToDisplay[i];
  }
  setPlayers(playersToDisplayTrimmed);
}

function disqualifyPlayer(address player) {
  if (!PlayerMetadata.getIsRegistered(player)) {
    return;
  }
  if (PlayerMetadata.getIsDisqualified(player)) {
    return;
  }
  PlayerMetadata.setIsDisqualified(player, true);
  setNotification(address(0), string.concat("Player ", Strings.toHexString(player), " has been disqualified"));
}
