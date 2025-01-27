// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAdmin } from "@biomesaw/experience/src/codegen/tables/ChipAdmin.sol";
import { DisplayContentData } from "@biomesaw/world/src/codegen/tables/DisplayContent.sol";
import { getForceField, isApproved } from "@biomesaw/experience/src/utils/ForceFieldUtils.sol";

import { Metadata } from "./codegen/tables/Metadata.sol";
import { TextSign } from "./codegen/tables/TextSign.sol";
import { IChip } from "./IChip.sol";
import { isApprovedForGate } from "@biomesaw/experience/src/utils/GateUtils.sol";

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

  function setDisplayApprovals(bytes32 entityId, address[] memory players, address[] memory nfts) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.setApprovedPlayers(entityId, players);
    chip.setApprovedNFTs(entityId, nfts);
  }

  function getDisplayContent(bytes32 entityId) public view returns (DisplayContentData memory) {
    IChip chip = getChipContract();
    return chip.getDisplayContent(entityId);
  }

  function setDisplayText(bytes32 entityId, string memory text) public {
    require(isApprovedForGate(entityId, _msgSender()), "Only approved players can set the display text");
    TextSign.set(entityId, text);
  }
}
