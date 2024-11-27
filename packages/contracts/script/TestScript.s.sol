// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";
import { ImageDisplay } from "../src/codegen/tables/ImageDisplay.sol";
import { IChip } from "../src/IChip.sol";

contract TestScript is Script {
  function run(address worldAddress) external {
    // Specify a store so that you can use tables directly in PostDeploy
    StoreSwitch.setStoreAddress(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    console.log("Using Chip contract at address: ");
    address chipAddress = Metadata.getChipAddress();
    console.logAddress(chipAddress);
    IChip chip = IChip(chipAddress);

    bytes32 entityId = 0x0000000000000000000000000000000000000000000000000000000000001415;
    console.log(ImageDisplay.get(entityId));
    console.logBytes(abi.encode(ImageDisplay.get(entityId)));

    // ImageDisplay.set(entityId, "https://example.com/image.png");

    vm.stopBroadcast();
  }
}
