// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";
import { IExperience } from "../src/IExperience.sol";

import { Players } from "@biomesaw/experience/src/codegen/tables/Players.sol";
import { PlayerMetadata, PlayerMetadataData } from "../src/codegen/tables/PlayerMetadata.sol";

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

    IExperience(experienceAddress).joinExperience{ value: 350000000000000 }();

    // IExperience(experienceAddress).withdraw();

    address[] memory players = Players.get(experienceAddress);
    for (uint i = 0; i < players.length; i++) {
      console.log("Player");
      console.logAddress(players[i]);
      console.logUint(PlayerMetadata.getBalance(players[i]));
      console.logAddress(PlayerMetadata.getLastHitter(players[i]));
    }

    vm.stopBroadcast();
  }
}
