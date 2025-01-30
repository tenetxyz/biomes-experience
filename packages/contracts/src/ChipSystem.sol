// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAdmin } from "@biomesaw/experience/src/codegen/tables/ChipAdmin.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { IChip } from "./IChip.sol";
import { PipeTransferData } from "@biomesaw/world/src/Types.sol";
import { ChipData } from "@biomesaw/world/src/codegen/tables/Chip.sol";
import { getForceField, getLatestChipData } from "@biomesaw/experience/src/utils/ForceFieldUtils.sol";
import { SecurityLevel } from "./codegen/tables/SecurityLevel.sol";
import { CHARGE_PER_BATTERY } from "@biomesaw/world/src/Constants.sol";

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

  function chargeForceField(bytes32 chestEntityId, PipeTransferData memory pipeTransferData) public {
    IChip chip = getChipContract();
    chip.chargeForceField(chestEntityId, pipeTransferData);
  }

  function shouldChargeForceField(bytes32 chestEntityId) public view returns (bytes32, uint256) {
    ChipData memory chestChipData = getLatestChipData(chestEntityId);
    bytes32 chestForceFieldEntityId = getForceField(chestEntityId);
    require(chestForceFieldEntityId != bytes32(0), "Force field not found");
    ChipData memory chestForceFieldChipData = getLatestChipData(chestForceFieldEntityId);
    chestChipData.batteryLevel += chestForceFieldChipData.batteryLevel;

    uint256 targetSecurityLevel = SecurityLevel.get(chestEntityId);
    if (chestChipData.batteryLevel < targetSecurityLevel) {
      uint256 deltaLevel = targetSecurityLevel - chestChipData.batteryLevel;
      uint256 numBatteriesNeeded = (deltaLevel + CHARGE_PER_BATTERY - 1) / CHARGE_PER_BATTERY;
      return (chestForceFieldEntityId, numBatteriesNeeded);
    }
    return (bytes32(0), 0);
  }
}
