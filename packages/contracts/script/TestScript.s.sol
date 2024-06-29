// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

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

contract TestScript is Script {
  function run(address worldAddress) external {
    // Specify a store so that you can use tables directly in PostDeploy
    StoreSwitch.setStoreAddress(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    Notifications.set(address(0), "Test Notification");

    vm.stopBroadcast();
  }
}
