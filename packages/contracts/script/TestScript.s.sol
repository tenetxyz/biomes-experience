// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";
import { IExperience } from "../src/IExperience.sol";

import { BuildWithPos } from "@biomesaw/experience/src/utils/BuildUtils.sol";

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

    uint8[] memory objectTypeIds = new uint8[](32);
    objectTypeIds[0] = 37;
    objectTypeIds[1] = 37;
    objectTypeIds[2] = 37;
    objectTypeIds[3] = 37;
    objectTypeIds[4] = 37;
    objectTypeIds[5] = 37;
    objectTypeIds[6] = 37;
    objectTypeIds[7] = 37;
    objectTypeIds[8] = 34;
    objectTypeIds[9] = 34;
    objectTypeIds[10] = 34;
    objectTypeIds[11] = 37;
    objectTypeIds[12] = 34;
    objectTypeIds[13] = 34;
    objectTypeIds[14] = 34;
    objectTypeIds[15] = 37;
    objectTypeIds[16] = 37;
    objectTypeIds[17] = 34;
    objectTypeIds[18] = 34;
    objectTypeIds[19] = 37;
    objectTypeIds[20] = 37;
    objectTypeIds[21] = 34;
    objectTypeIds[22] = 34;
    objectTypeIds[23] = 37;
    objectTypeIds[24] = 37;
    objectTypeIds[25] = 37;
    objectTypeIds[26] = 37;
    objectTypeIds[27] = 37;
    objectTypeIds[28] = 37;
    objectTypeIds[29] = 37;
    objectTypeIds[30] = 37;
    objectTypeIds[31] = 37;

    VoxelCoord[] memory relativePositions = new VoxelCoord[](32);
    relativePositions[0] = VoxelCoord(0, 0, 0);
    relativePositions[1] = VoxelCoord(0, 0, 1);
    relativePositions[2] = VoxelCoord(0, 0, 2);
    relativePositions[3] = VoxelCoord(0, 0, 3);
    relativePositions[4] = VoxelCoord(0, 1, 0);
    relativePositions[5] = VoxelCoord(0, 1, 1);
    relativePositions[6] = VoxelCoord(0, 1, 2);
    relativePositions[7] = VoxelCoord(0, 1, 3);
    relativePositions[8] = VoxelCoord(1, 0, 0);
    relativePositions[9] = VoxelCoord(1, 0, 1);
    relativePositions[10] = VoxelCoord(1, 0, 2);
    relativePositions[11] = VoxelCoord(1, 0, 3);
    relativePositions[12] = VoxelCoord(1, 1, 0);
    relativePositions[13] = VoxelCoord(1, 1, 1);
    relativePositions[14] = VoxelCoord(1, 1, 2);
    relativePositions[15] = VoxelCoord(1, 1, 3);
    relativePositions[16] = VoxelCoord(2, 0, 0);
    relativePositions[17] = VoxelCoord(2, 0, 1);
    relativePositions[18] = VoxelCoord(2, 0, 2);
    relativePositions[19] = VoxelCoord(2, 0, 3);
    relativePositions[20] = VoxelCoord(2, 1, 0);
    relativePositions[21] = VoxelCoord(2, 1, 1);
    relativePositions[22] = VoxelCoord(2, 1, 2);
    relativePositions[23] = VoxelCoord(2, 1, 3);
    relativePositions[24] = VoxelCoord(3, 0, 0);
    relativePositions[25] = VoxelCoord(3, 0, 1);
    relativePositions[26] = VoxelCoord(3, 0, 2);
    relativePositions[27] = VoxelCoord(3, 0, 3);
    relativePositions[28] = VoxelCoord(3, 1, 0);
    relativePositions[29] = VoxelCoord(3, 1, 1);
    relativePositions[30] = VoxelCoord(3, 1, 2);
    relativePositions[31] = VoxelCoord(3, 1, 3);

    VoxelCoord memory baseWorldCoord = VoxelCoord(380, 17, -179);

    IExperience(experienceAddress).setGuardBuild(
      "Protection House",
      BuildWithPos({
        objectTypeIds: objectTypeIds,
        relativePositions: relativePositions,
        baseWorldCoord: baseWorldCoord
      })
    );

    // IExperience(experienceAddress).hitIntruder(0x1B1240e0c3F3D4EB227916aB2BEb86E01C85d48f);

    // IExperience(experienceAddress).addAllowedPlayer(0x1B1240e0c3F3D4EB227916aB2BEb86E01C85d48f);
    // IExperience(experienceAddress).setGuardPosition(VoxelCoord(381, 17, -179));
    // VoxelCoord[] memory unguardPositions = new VoxelCoord[](2);
    // unguardPositions[0] = VoxelCoord(381, 17, -180);
    // unguardPositions[1] = VoxelCoord(381, 17, -181);

    // IExperience(experienceAddress).setUnguardPosition(unguardPositions);

    vm.stopBroadcast();
  }
}
