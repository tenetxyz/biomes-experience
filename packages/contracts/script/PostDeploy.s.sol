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
import { Chip } from "../src/Chip.sol";
import { CHIP_NAMESPACE } from "../src/Constants.sol";

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
      namespace: CHIP_NAMESPACE,
      name: ""
    });

    address currentChipAddress = Metadata.getChipAddress();
    if (currentChipAddress != address(0)) {
      console.log("Revoking access to current Chip contract...");
      IWorld(worldAddress).revokeAccess(namespaceId, currentChipAddress);
    }

    console.log("Deploying Chip contract...");
    Chip chip = new Chip(worldAddress);
    console.log("Deployed Chip contract at address: ");
    address chipAddress = address(chip);
    console.logAddress(chipAddress);
    IWorld(worldAddress).grantAccess(namespaceId, chipAddress);
    Metadata.setChipAddress(chipAddress);

    chipAddress.call(abi.encodeWithSignature("addAllowedSetup(address)", 0xE0ae70caBb529336e25FA7a1f036b77ad0089d2a));

    vm.stopBroadcast();
  }
}
