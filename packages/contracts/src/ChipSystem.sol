// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";

import { Metadata } from "./codegen/tables/Metadata.sol";
import { IChip } from "./IChip.sol";

contract ChipSystem is System {
  function getChipContract() internal view returns (IChip) {
    return IChip(Metadata.getChipAddress());
  }

  function onlyAttacher(bytes32 entityId) internal view {
    require(ChipAttachment.getAttacher(entityId) == _msgSender(), "Only the attacher can call this function");
  }

  function setDisplayData(bytes32 entityId, string memory name, string memory description) public {
    onlyAttacher(entityId);
    IChip chip = getChipContract();
    chip.setDisplayData(entityId, name, description);
  }
}
