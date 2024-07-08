// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";
import { IExperience } from "../src/IExperience.sol";

import { Area } from "@biomesaw/experience/src/utils/AreaUtils.sol";
import { GameMetadata } from "../src/codegen/tables/GameMetadata.sol";
import { PlayerMetadata } from "../src/codegen/tables/PlayerMetadata.sol";

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

    IExperience(experienceAddress).setMatchArea(
      "Match Area",
      Area({
        lowerSouthwestCorner: VoxelCoord({ x: 271, y: -150, z: -235 }),
        size: VoxelCoord({ x: 60, y: 250, z: 60 })
      })
    );

    // IExperience(experienceAddress).joinExperience{ value: 1400000000000000 }();

    // IExperience(experienceAddress).startGame(30);
    // IExperience(experienceAddress).claimRewardPool();
    address[] memory registeredPlayers = GameMetadata.getPlayers();
    for (uint i = 0; i < registeredPlayers.length; i++) {
      console.logAddress(registeredPlayers[i]);
      console.logUint(PlayerMetadata.getNumKills(registeredPlayers[i]));
    }

    vm.stopBroadcast();
  }
}
