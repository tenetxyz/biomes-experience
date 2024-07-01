// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IWorld } from "../codegen/world/IWorld.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { System } from "@latticexyz/world/src/System.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { SystemRegistry } from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import { Balances } from "@latticexyz/world/src/codegen/tables/Balances.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { Hook } from "@latticexyz/store/src/Hook.sol";
import { ICustomUnregisterDelegation } from "@latticexyz/world/src/ICustomUnregisterDelegation.sol";
import { IOptionalSystemHook } from "@latticexyz/world/src/IOptionalSystemHook.sol";
import { Utils } from "@latticexyz/world/src/Utils.sol";
import { AccessControlLib } from "@latticexyz/world-modules/src/utils/AccessControlLib.sol";
import { IERC165 } from "@latticexyz/world/src/IERC165.sol";
import { WorldContextConsumer } from "@latticexyz/world/src/WorldContext.sol";

import { ExperienceMetadata, ExperienceMetadataData } from "../codegen/tables/ExperienceMetadata.sol";
import { DisplayStatus } from "../codegen/tables/DisplayStatus.sol";
import { DisplayRegisterMsg } from "../codegen/tables/DisplayRegisterMsg.sol";
import { DisplayUnregisterMsg } from "../codegen/tables/DisplayUnregisterMsg.sol";
import { Notifications } from "../codegen/tables/Notifications.sol";
import { Players } from "../codegen/tables/Players.sol";
import { Areas, AreasData } from "../codegen/tables/Areas.sol";
import { Builds, BuildsData } from "../codegen/tables/Builds.sol";
import { BuildsWithPos, BuildsWithPosData } from "../codegen/tables/BuildsWithPos.sol";
import { Countdown } from "../codegen/tables/Countdown.sol";
import { Tokens } from "../codegen/tables/Tokens.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { voxelCoordsAreEqual, inSurroundingCube } from "@biomesaw/utils/src/VoxelCoordUtils.sol";

// Available utils, remove the ones you don't need
// See ObjectTypeIds.sol for all available object types
import { PlayerObjectID, AirObjectID, DirtObjectID, ChestObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { getBuildArgs, getMineArgs, getMoveArgs, getHitArgs, getDropArgs, getTransferArgs, getCraftArgs, getEquipArgs, getLoginArgs, getSpawnArgs } from "../utils/HookUtils.sol";
import { getSystemId, getNamespaceSystemId, isSystemId, callBuild, callMine, callMove, callHit, callDrop, callTransfer, callCraft, callEquip, callUnequip, callLogin, callLogout, callSpawn, callActivate } from "../utils/DelegationUtils.sol";
import { hasBeforeAndAfterSystemHook, hasDelegated, getObjectTypeAtCoord, getEntityAtCoord, getPosition, getObjectType, getMiningDifficulty, getStackable, getDamage, getDurability, isTool, isBlock, getEntityFromPlayer, getPlayerFromEntity, getEquipped, getHealth, getStamina, getIsLoggedOff, getLastHitTime, getInventoryTool, getInventoryObjects, getCount, getNumSlotsUsed, getNumUsesLeft } from "../utils/EntityUtils.sol";
import { Area, insideArea, insideAreaIgnoreY, getEntitiesInArea } from "../utils/AreaUtils.sol";
import { Build, BuildWithPos, buildExistsInWorld, buildWithPosExistsInWorld } from "../utils/BuildUtils.sol";
import { NamedArea, NamedBuild, NamedBuildWithPos, weiToString, getEmptyBlockOnGround } from "../utils/GameUtils.sol";

import { IExperienceSystem } from "../prototypes/IExperienceSystem.sol";
import { EXPERIENCE_NAMESPACE } from "../Constants.sol";

// Functions that are called by EOAs
contract ExperienceSystem is IExperienceSystem {
  function joinExperience() public payable override {
    super.joinExperience();
  }

  function initExperience() public {
    AccessControlLib.requireOwner(SystemRegistry.get(address(this)), _msgSender());

    DisplayStatus.set("Test Experience Status");
    DisplayRegisterMsg.set("Test Experience Register Message");
    DisplayUnregisterMsg.set("Test Experience Unregister Message");

    address worldSystemAddress = Systems.getSystem(getNamespaceSystemId(EXPERIENCE_NAMESPACE, "WorldSystem"));
    require(worldSystemAddress != address(0), "WorldSystem not found");

    bytes32[] memory hookSystemIds = new bytes32[](1);
    hookSystemIds[0] = ResourceId.unwrap(getSystemId("MoveSystem"));

    ExperienceMetadata.set(
      ExperienceMetadataData({
        contractAddress: worldSystemAddress,
        shouldDelegate: false,
        hookSystemIds: hookSystemIds,
        joinFee: 0,
        name: "Test Experience",
        description: "Test Experience Description"
      })
    );
  }
}
