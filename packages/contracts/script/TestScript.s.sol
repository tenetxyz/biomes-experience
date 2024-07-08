// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";
import { IExperience } from "../src/IExperience.sol";
import { GrassObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";

contract TestScript is Script {
  function run(address worldAddress) external {
    // Specify a store so that you can use tables directly in PostDeploy
    StoreSwitch.setStoreAddress(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    console.log("Using Experience contract at address: ");
    address experienceAddress = Metadata.getExperienceAddress();
    console.logAddress(experienceAddress);

    IExperience(experienceAddress).setVaultChestCoord(VoxelCoord(375, 17, -194));

    // IExperience(experienceAddress).withdraw(
    //   GrassObjectID,
    //   2,
    //   0x0000000000000000000000000000000000000000000000000000000000001415
    // );
    // IExperience(experienceAddress).withdrawTool(
    //   0x0000000000000000000000000000000000000000000000000000000000001439,
    //   0x0000000000000000000000000000000000000000000000000000000000001415
    // );

    vm.stopBroadcast();
  }
}
