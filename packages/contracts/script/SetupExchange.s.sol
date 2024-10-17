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
import { Exchange } from "../src/codegen/tables/Exchange.sol";
import { Chip } from "../src/Chip.sol";
import { CHIP_NAMESPACE } from "../src/Constants.sol";

import { Chip as ChipTable } from "@biomesaw/world/src/codegen/tables/Chip.sol";

import { getObjectType } from "@biomesaw/experience/src/utils/EntityUtils.sol";
import { ChestObjectID, CoalOreObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { testAddToInventoryCount } from "@biomesaw/world/test/utils/TestUtils.sol";

struct ItemConfig {
  bytes32 chestEntityId;
  uint256 objectTypeId;
  uint256 targetPrice;
}

struct BazaarConfig {
  ItemConfig[] items;
}

contract SetupExchange is Script {
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

    address paymentToken = 0x2FF827f8750dbe1A7dbAD0f7354d0D0395551d2F;

    for (uint i = 0; i < bazaarConfig.items.length; i++) {
      ItemConfig memory item = bazaarConfig.items[i];
      uint8 objectTypeId = uint8(item.objectTypeId);

      // The target price for a token if sold on pace, scaled by 1e18.
      int256 targetPrice = int256(item.targetPrice);
      bytes32 chestEntityId = item.chestEntityId;
      require(getObjectType(chestEntityId) == ChestObjectID, "Invalid chest entity ID");

      uint256 initialCurrencyAmount = (uint256(targetPrice) * uint256(6 * 99));
      uint256 initialItemAmount = uint256(6 * 99);
      uint256 exchangeConstant = initialItemAmount * initialCurrencyAmount;
      // Exchange.set(objectTypeId, exchangeConstant);

      require(ChipTable.getChipAddress(chestEntityId) == chipAddress, "Invalid chip address");

      // IERC20(paymentToken).approve(chipAddress, initialCurrencyAmount);
      // chipAddress.call(
      //   abi.encodeWithSignature(
      //     "setupBuySellShop(bytes32,uint8,uint256,uint256,uint256,address)",
      //     chestEntityId,
      //     objectTypeId,
      //     targetPrice,
      //     initialItemAmount,
      //     targetPrice,
      //     paymentToken
      //   )
      // );

      ChipTable.setBatteryLevel(chestEntityId, 10 weeks);
      ChipTable.setLastUpdatedTime(chestEntityId, block.timestamp);
      testAddToInventoryCount(chestEntityId, ChestObjectID, objectTypeId, uint16(initialItemAmount));
    }

    // chipAddress.call(abi.encodeWithSignature("setExchangeToken(address)", paymentToken));

    vm.stopBroadcast();
  }
}
