// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { IExperienceSystem } from "../codegen/world/IExperienceSystem.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { ICustomUnregisterDelegation } from "@latticexyz/world/src/ICustomUnregisterDelegation.sol";
import { IOptionalSystemHook } from "@latticexyz/world/src/IOptionalSystemHook.sol";
import { ISystemHook } from "@latticexyz/world/src/ISystemHook.sol";
import { AccessControlLib } from "@latticexyz/world-modules/src/utils/AccessControlLib.sol";

import { getSystemId, getNamespaceSystemId } from "@biomesaw/experience/src/utils/DelegationUtils.sol";
import { ExperienceMetadata, ExperienceMetadataData } from "@biomesaw/experience/src/codegen/tables/ExperienceMetadata.sol";
import { hasBeforeAndAfterSystemHook, hasDelegated } from "@biomesaw/experience/src/utils/EntityUtils.sol";
import { setNamespaceExperience, deleteNamespaceExperience } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";

import { CallMetadata } from "../codegen/tables/CallMetadata.sol";
import { EXPERIENCE_NAMESPACE } from "../Constants.sol";

abstract contract IExternalSystem is System {
  function initExperience() public virtual {
    AccessControlLib.requireOwner(SystemRegistry.get(address(this)), _msgSender());

    address experienceAddress = Systems.getSystem(getNamespaceSystemId(EXPERIENCE_NAMESPACE, "WorldSystem"));
    require(experienceAddress != address(0), "WorldSystem not found");

    setNamespaceExperience(experienceAddress);

    CallMetadata.set(
      ICustomUnregisterDelegation.canUnregister.selector,
      IExperienceSystem.testexperience___canUnregister.selector
    );
    CallMetadata.set(
      IOptionalSystemHook.onRegisterHook.selector,
      IExperienceSystem.testexperience___onRegisterHook.selector
    );
    CallMetadata.set(
      IOptionalSystemHook.onUnregisterHook.selector,
      IExperienceSystem.testexperience___onUnregisterHook.selector
    );
    CallMetadata.set(
      ISystemHook.onBeforeCallSystem.selector,
      IExperienceSystem.testexperience___onBeforeCallSystem.selector
    );
    CallMetadata.set(
      ISystemHook.onAfterCallSystem.selector,
      IExperienceSystem.testexperience___onAfterCallSystem.selector
    );
  }

  function joinExperience() public payable virtual {
    address experienceAddress = Systems.getSystem(getNamespaceSystemId(EXPERIENCE_NAMESPACE, "ExperienceSystem"));
    require(experienceAddress != address(0), "ExperienceSystem not found");

    require(_msgValue() >= ExperienceMetadata.getJoinFee(experienceAddress), "The player hasn't paid the join fee");

    address player = _msgSender();

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
