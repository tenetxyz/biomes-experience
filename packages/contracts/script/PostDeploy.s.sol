// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Experience } from "../src/Experience.sol";
import { Config } from "../src/codegen/tables/Config.sol";
import { EXPERIENCE_NAMESPACE } from "../src/Constants.sol";

contract PostDeploy is Script {
  function run(address worldAddress) external {
    // Specify a store so that you can use tables directly in PostDeploy
    StoreSwitch.setStoreAddress(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    ResourceId namespaceId = WorldResourceIdLib.encode({
      typeId: RESOURCE_NAMESPACE,
      namespace: EXPERIENCE_NAMESPACE,
      name: ""
    });
    console.log("Deploying Experience contract...");
    Experience experience = new Experience(worldAddress);
    console.log("Deployed Experience contract at address: ");
    console.logAddress(address(experience));
    IWorld(worldAddress).grantAccess(namespaceId, address(experience));

    Config.setConractAddress(address(experience));
    IWorld(worldAddress).testexperience__initExperience();

    vm.stopBroadcast();
  }
}
