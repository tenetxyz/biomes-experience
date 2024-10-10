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
import { Exchange, ExchangeData } from "../src/codegen/tables/Exchange.sol";
import { Chip } from "../src/Chip.sol";
import { CHIP_NAMESPACE } from "../src/Constants.sol";

import { CoalOreObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";

contract DeploySingle is Script {
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

    uint8 objectTypeId = CoalOreObjectID;
    // The target price for a token if sold on pace, scaled by 1e18.
    int256 targetPrice = 5e18;
    // The percent price decays per unit of time with no sales, scaled by 1e18.
    int256 priceDecayPercent = 0.77e18;
    /// The number of tokens to target selling in 1 full unit of time, scaled by 1e18.
    int256 perTimeUnit = 20e18;
    // Custom parameter to scale the VRGDA price
    uint256 rarity = 5;
    address exchangeToken = 0x2FF827f8750dbe1A7dbAD0f7354d0D0395551d2F;

    address currentChipAddress = Metadata.getChipAddress(objectTypeId);
    if (currentChipAddress != address(0)) {
      console.log("Revoking access to current Chip contract...");
      IWorld(worldAddress).revokeAccess(namespaceId, currentChipAddress);
    }

    console.log("Deploying Chip contract...");
    Chip chip = new Chip(worldAddress, objectTypeId, targetPrice, priceDecayPercent, perTimeUnit);
    console.log("Deployed Chip contract at address: ");
    address chipAddress = address(chip);
    console.logAddress(chipAddress);
    IWorld(worldAddress).grantAccess(namespaceId, chipAddress);
    Metadata.set(objectTypeId, chipAddress, exchangeToken);

    Exchange.set(
      objectTypeId,
      ExchangeData({ price: uint256(targetPrice), lastPurchaseTime: 0, sold: 0, rarity: rarity })
    );

    vm.stopBroadcast();
  }
}
