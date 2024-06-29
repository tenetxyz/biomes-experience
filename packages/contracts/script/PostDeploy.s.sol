// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { Systems } from "@latticexyz/world/src/codegen/tables/Systems.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { ExperienceMetadata, ExperienceMetadataData } from "../src/codegen/tables/ExperienceMetadata.sol";
import { DisplayMetadata, DisplayMetadataData } from "../src/codegen/tables/DisplayMetadata.sol";
import { Notifications } from "../src/codegen/tables/Notifications.sol";
import { Players } from "../src/codegen/tables/Players.sol";
import { Areas } from "../src/codegen/tables/Areas.sol";
import { Builds } from "../src/codegen/tables/Builds.sol";
import { BuildsWithPos } from "../src/codegen/tables/BuildsWithPos.sol";
import { Countdown } from "../src/codegen/tables/Countdown.sol";
import { Tokens } from "../src/codegen/tables/Tokens.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";

import { getSystemId, getNamespaceSystemId } from "../src/utils/DelegationUtils.sol";
import { EXPERIENCE_NAMESPACE } from "../src/Constants.sol";

contract PostDeploy is Script {
  function run(address worldAddress) external {
    // Specify a store so that you can use tables directly in PostDeploy
    StoreSwitch.setStoreAddress(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    DisplayMetadata.set(
      DisplayMetadataData({
        status: "Test Experience Status",
        registerMessage: "Test Experience Register Message",
        unregisterMessage: "Test Experience Unregister Message"
      })
    );

    address experienceSystemAddress = Systems.getSystem(getNamespaceSystemId(EXPERIENCE_NAMESPACE, "ExperienceSystem"));
    require(experienceSystemAddress != address(0), "ExperienceSystem not found");

    bytes32[] memory hookSystemIds = new bytes32[](1);
    hookSystemIds[0] = ResourceId.unwrap(getSystemId("MoveSystem"));

    ExperienceMetadata.set(
      ExperienceMetadataData({
        contractAddress: experienceSystemAddress,
        shouldDelegate: false,
        hookSystemIds: hookSystemIds,
        name: "Test Experience",
        description: "Test Experience Description"
      })
    );

    vm.stopBroadcast();
  }
}
