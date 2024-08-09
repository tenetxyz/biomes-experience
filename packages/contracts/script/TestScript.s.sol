// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";
import { IExperience } from "../src/IExperience.sol";

import { Builder } from "../src/codegen/tables/Builder.sol";
import { BuildMetadata, BuildMetadataData } from "../src/codegen/tables/BuildMetadata.sol";
import { PlayerMetadata } from "../src/codegen/tables/PlayerMetadata.sol";
import { BuildIds } from "../src/codegen/tables/BuildIds.sol";
import { Build } from "@biomesaw/experience/src/utils/BuildUtils.sol";

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

    uint8[] memory objectTypeIds = new uint8[](6);
    objectTypeIds[0] = 42;
    objectTypeIds[1] = 42;
    objectTypeIds[2] = 42;
    objectTypeIds[3] = 34;
    objectTypeIds[4] = 42;
    objectTypeIds[5] = 34;

    VoxelCoord[] memory relativePositions = new VoxelCoord[](6);
    relativePositions[0] = VoxelCoord(0, 0, 0);
    relativePositions[1] = VoxelCoord(0, 0, 1);
    relativePositions[2] = VoxelCoord(0, 0, 2);
    relativePositions[3] = VoxelCoord(0, 1, 0);
    relativePositions[4] = VoxelCoord(0, 1, 1);
    relativePositions[5] = VoxelCoord(0, 1, 2);

    uint256 submissionPrice = 10000000000000000;
    IExperience(experienceAddress).create(
      "Test Building",
      submissionPrice,
      Build({ objectTypeIds: objectTypeIds, relativePositions: relativePositions })
    );

    uint256 buildingId = 1;

    // IExperience(experienceAddress).submitBuilding{ value: submissionPrice }(buildingId, VoxelCoord(302, 13, -249));

    // IExperience(experienceAddress).challengeBuilding(buildingId, 0);

    BuildMetadataData memory buildMetadata = BuildMetadata.get(bytes32(buildingId));

    console.log("Builds");
    for (uint i = 0; i < buildMetadata.builders.length; i++) {
      console.logAddress(buildMetadata.builders[i]);
      console.logInt(buildMetadata.locationsX[i]);
      console.logInt(buildMetadata.locationsY[i]);
      console.logInt(buildMetadata.locationsZ[i]);
    }

    vm.stopBroadcast();
  }
}
