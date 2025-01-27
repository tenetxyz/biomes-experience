// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAdmin } from "@biomesaw/experience/src/codegen/tables/ChipAdmin.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { IChip } from "./IChip.sol";
import { isApprovedPlayerForGate, isApprovedForGate } from "@biomesaw/experience/src/utils/GateUtils.sol";
import { GateApprovals } from "@biomesaw/experience/src/codegen/tables/GateApprovals.sol";

contract ChipSystem is System {
  function getChipContract() internal view returns (IChip) {
    return IChip(Metadata.getChipAddress());
  }

  function onlyAdmin(bytes32 entityId) internal view {
    require(ChipAdmin.get(entityId) == _msgSender(), "Only the admin can call this function");
  }

  function changeAdmin(bytes32 entityId, address newAdmin) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.changeAdmin(entityId, newAdmin);
  }

  function setDisplayData(bytes32 entityId, string memory name, string memory description) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.setDisplayData(entityId, name, description);
  }

  function addApprovedPlayer(bytes32 entityId, address player) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();

    address[] memory approvedPlayers = GateApprovals.getPlayers(entityId);
    address[] memory newApprovedPlayers = new address[](approvedPlayers.length + 1);
    for (uint256 i = 0; i < approvedPlayers.length; i++) {
      require(approvedPlayers[i] != player, "Player is already approved");
      newApprovedPlayers[i] = approvedPlayers[i];
    }
    newApprovedPlayers[approvedPlayers.length] = player;

    chip.setApprovedPlayers(entityId, newApprovedPlayers);
  }

  function removeApprovedPlayer(bytes32 entityId, address player) public {
    require(isApprovedPlayerForGate(entityId, player), "Player is not approved");
    onlyAdmin(entityId);
    IChip chip = getChipContract();

    address[] memory approvedPlayers = GateApprovals.getPlayers(entityId);
    address[] memory newApprovedPlayers = new address[](approvedPlayers.length - 1);
    uint256 j = 0;
    for (uint256 i = 0; i < approvedPlayers.length; i++) {
      if (approvedPlayers[i] == player) {
        continue;
      }
      newApprovedPlayers[j] = approvedPlayers[i];
      j++;
    }

    chip.setApprovedPlayers(entityId, newApprovedPlayers);
  }

  function addApprovedNFT(bytes32 entityId, address nft) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();

    address[] memory approvedNfts = GateApprovals.getNfts(entityId);
    address[] memory newApprovedNfts = new address[](approvedNfts.length + 1);
    for (uint256 i = 0; i < approvedNfts.length; i++) {
      require(approvedNfts[i] != nft, "NFT is already approved");
      newApprovedNfts[i] = approvedNfts[i];
    }
    newApprovedNfts[approvedNfts.length] = nft;

    chip.setApprovedNFTs(entityId, newApprovedNfts);
  }

  function removeApprovedNFT(bytes32 entityId, address nft) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();

    address[] memory approvedNfts = GateApprovals.getNfts(entityId);
    bool hasApprovedNft = false;
    for (uint256 i = 0; i < approvedNfts.length; i++) {
      if (approvedNfts[i] == nft) {
        hasApprovedNft = true;
        break;
      }
    }
    require(hasApprovedNft, "NFT is not approved");
    address[] memory newApprovedNfts = new address[](approvedNfts.length - 1);
    uint256 j = 0;
    for (uint256 i = 0; i < approvedNfts.length; i++) {
      if (approvedNfts[i] == nft) {
        continue;
      }
      newApprovedNfts[j] = approvedNfts[i];
      j++;
    }

    chip.setApprovedNFTs(entityId, newApprovedNfts);
  }

  function setApprovedPlayers(bytes32 entityId, address[] memory players) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.setApprovedPlayers(entityId, players);
  }

  function setApprovedNFTs(bytes32 entityId, address[] memory nfts) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.setApprovedNFTs(entityId, nfts);
  }

  function setForceFieldApprovals(bytes32 entityId, address[] memory players, address[] memory nfts) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.setApprovedPlayers(entityId, players);
    chip.setApprovedNFTs(entityId, nfts);
  }
}
