// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
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

struct ItemConfig {
  uint256 objectTypeId;
  uint256 perTimeUnit;
  uint256 priceDecayPercent;
  uint256 targetPrice;
}

struct BazaarConfig {
  ItemConfig[] items;
}

contract DeployChips is Script {
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

    BazaarConfig memory bazaarConfig;
    {
      string memory root = vm.projectRoot();
      string memory path = string.concat(root, "/script/config.json");
      string memory json = vm.readFile(path);
      bytes memory data = vm.parseJson(json);
      bazaarConfig = abi.decode(data, (BazaarConfig));
    }

    string memory deploymentsJson = '{ "chips": [';

    for (uint i = 0; i < bazaarConfig.items.length; i++) {
      ItemConfig memory item = bazaarConfig.items[i];
      uint8 objectTypeId = uint8(item.objectTypeId);

      // The target price for a token if sold on pace, scaled by 1e18.
      int256 targetPrice = int256(item.targetPrice);
      // The percent price decays per unit of time with no sales, scaled by 1e18.
      int256 priceDecayPercent = int256(item.priceDecayPercent);
      /// The number of tokens to target selling in 1 full unit of time, scaled by 1e18.

      // Note: The JSON assumes per day, but our time unit is per 3 days so we multiply it here
      int256 perTimeUnit = int256(item.perTimeUnit) * 3;

      // Custom parameter to scale the VRGDA price
      address exchangeToken = 0x2FF827f8750dbe1A7dbAD0f7354d0D0395551d2F;

      console.log("------------------------------------");
      address currentChipAddress = Metadata.getChipAddress(objectTypeId);
      if (currentChipAddress != address(0)) {
        console.log(string.concat("Revoking access to current Chip contract...", Strings.toString(objectTypeId)));
        IWorld(worldAddress).revokeAccess(namespaceId, currentChipAddress);
      }

      console.log(string.concat("Deploying Chip contract for object type: ", Strings.toString(objectTypeId)));
      console.log(string.concat("Target price: ", Strings.toString(uint256(targetPrice))));
      console.log(string.concat("Price decay percent: ", Strings.toString(uint256(priceDecayPercent))));
      console.log(string.concat("Per time unit: ", Strings.toString(uint256(perTimeUnit))));
      Chip chip = new Chip(worldAddress, objectTypeId, targetPrice, priceDecayPercent, perTimeUnit);
      console.log(string.concat("Deployed Chip contract at address: ", Strings.toString(objectTypeId)));
      address chipAddress = address(chip);
      console.logAddress(chipAddress);
      console.log("------------------------------------");
      IWorld(worldAddress).grantAccess(namespaceId, chipAddress);
      Metadata.set(objectTypeId, chipAddress, exchangeToken);

      Exchange.set(objectTypeId, ExchangeData({ price: uint256(targetPrice), lastPurchaseTime: 0, sold: 0 }));

      deploymentsJson = string(
        abi.encodePacked(
          deploymentsJson,
          '{ "objectTypeId": "',
          Strings.toString(objectTypeId),
          '", "address": "',
          Strings.toHexString(chipAddress),
          '" }'
        )
      );

      if (i < bazaarConfig.items.length - 1) {
        deploymentsJson = string(abi.encodePacked(deploymentsJson, ", "));
      }
    }

    deploymentsJson = string(abi.encodePacked(deploymentsJson, "] }"));

    // fetch already existing contracts
    {
      string memory root = vm.projectRoot();
      string memory path = string.concat(root, "/script/deployments/");
      string memory chainIdStr = vm.toString(block.chainid);
      path = string.concat(path, string.concat(chainIdStr, ".json"));
      vm.writeJson(deploymentsJson, path);
    }

    vm.stopBroadcast();
  }
}
