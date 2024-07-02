// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { ExperienceMetadata, ExperienceMetadataData } from "../codegen/tables/ExperienceMetadata.sol";
import { hasBeforeAndAfterSystemHook, hasDelegated } from "../utils/EntityUtils.sol";

abstract contract IExperienceSystem is System {
  function joinExperience() public payable virtual {
    require(_msgValue() >= ExperienceMetadata.getJoinFee(), "The player hasn't paid the join fee");

    address experienceAddress = ExperienceMetadata.getContractAddress();
    address player = _msgSender();

    bytes32[] memory hookSystemIds = ExperienceMetadata.getHookSystemIds();
    for (uint i = 0; i < hookSystemIds.length; i++) {
      ResourceId systemId = ResourceId.wrap(hookSystemIds[i]);
      require(
        hasBeforeAndAfterSystemHook(experienceAddress, player, systemId),
        string.concat("The player hasn't allowed the hook for: ", WorldResourceIdInstance.toString(systemId))
      );
    }

    if (player == ExperienceMetadata.getShouldDelegate()) {
      require(hasDelegated(player, experienceAddress), "The player hasn't delegated to the experience contract");
    }
  }
}
