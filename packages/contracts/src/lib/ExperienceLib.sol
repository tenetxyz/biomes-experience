// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { ExperienceMetadata, ExperienceMetadataData } from "@biomesaw/experience/src/codegen/tables/ExperienceMetadata.sol";
import { hasBeforeAndAfterSystemHook, hasDelegated } from "@biomesaw/experience/src/utils/EntityUtils.sol";

library ExperienceLib {
  function ensureJoinRequirements() public {
    address experienceAddress = address(this);
    require(msg.value >= ExperienceMetadata.getJoinFee(experienceAddress), "The player hasn't paid the join fee");

    address player = msg.sender;
    bytes32[] memory hookSystemIds = ExperienceMetadata.getHookSystemIds(experienceAddress);
    for (uint i = 0; i < hookSystemIds.length; i++) {
      ResourceId systemId = ResourceId.wrap(hookSystemIds[i]);
      require(
        hasBeforeAndAfterSystemHook(experienceAddress, player, systemId),
        string.concat("The player hasn't allowed the hook for: ", WorldResourceIdInstance.toString(systemId))
      );
    }

    if (player == ExperienceMetadata.getShouldDelegate(experienceAddress)) {
      require(hasDelegated(player, experienceAddress), "The player hasn't delegated to the experience contract");
    }
  }
}
