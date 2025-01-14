// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAdmin } from "@biomesaw/experience/src/codegen/tables/ChipAdmin.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { IChip } from "./IChip.sol";

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

  function setChestApprovals(bytes32 entityId, address[] memory players, address[] memory nfts) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.setApprovedPlayers(entityId, players);
    chip.setApprovedNFTs(entityId, nfts);
  }
}
