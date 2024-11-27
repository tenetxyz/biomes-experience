// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";
import { DisplayContent } from "@biomesaw/world/src/Types.sol";
import { getForceField, isApproved } from "@biomesaw/experience/src/utils/ForceFieldUtils.sol";

import { Metadata } from "./codegen/tables/Metadata.sol";
import { ImageDisplay } from "./codegen/tables/ImageDisplay.sol";
import { IChip } from "./IChip.sol";

contract ChipSystem is System {
  function getChipContract() internal view returns (IChip) {
    return IChip(Metadata.getChipAddress());
  }

  function onlyAttacher(bytes32 entityId) internal view {
    require(ChipAttachment.getAttacher(entityId) == _msgSender(), "Only the attacher can call this function");
  }

  function getDisplayContent(bytes32 entityId) public view returns (DisplayContent memory) {
    IChip chip = getChipContract();
    return chip.getDisplayContent(entityId);
  }

  function setDisplayImage(bytes32 entityId, string memory imageUrl) public {
    require(isApproved(getForceField(entityId), _msgSender()), "Only approved players can set the display text");
    ImageDisplay.set(entityId, imageUrl);
  }
}
