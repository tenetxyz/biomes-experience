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

  function configurePipeAccess(
    bytes32 chestEntityId,
    bytes32 callerEntityId,
    bool depositAllowed,
    bool withdrawAllowed
  ) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    chip.configurePipeAccess(chestEntityId, callerEntityId, depositAllowed, withdrawAllowed);
  }

  function configurePipeAccess(
    bytes32 chestEntityId,
    bytes32[] memory addCallerEntityIds,
    bytes32[] memory removeCallerEntityIds
  ) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    for (uint256 i = 0; i < addCallerEntityIds.length; i++) {
      chip.configurePipeAccess(chestEntityId, addCallerEntityIds[i], true, true);
    }
    for (uint256 i = 0; i < removeCallerEntityIds.length; i++) {
      chip.configurePipeAccess(chestEntityId, removeCallerEntityIds[i], false, false);
    }
  }
}
