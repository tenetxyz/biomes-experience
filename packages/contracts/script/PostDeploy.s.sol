// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { RESOURCE_NAMESPACE } from "@latticexyz/world/src/worldResourceTypes.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";
import { Experience } from "../src/Experience.sol";
import { EXPERIENCE_NAMESPACE } from "../src/Constants.sol";
import { IExperience } from "../src/IExperience.sol";

import { GameMetadata } from "../src/codegen/tables/GameMetadata.sol";

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

    address currentExperienceAddress = Metadata.getExperienceAddress();
    if (currentExperienceAddress != address(0)) {
      console.log("Revoking access to current Experience contract...");
      IWorld(worldAddress).revokeAccess(namespaceId, currentExperienceAddress);
    }

    console.log("Deploying Experience contract...");
    Experience experience = new Experience(worldAddress);
    console.log("Deployed Experience contract at address: ");
    address experienceAddress = address(experience);
    console.logAddress(experienceAddress);
    IWorld(worldAddress).grantAccess(namespaceId, experienceAddress);
    Metadata.setExperienceAddress(experienceAddress);

    GameMetadata.setGameStarter(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);

    vm.stopBroadcast();
  }
}
