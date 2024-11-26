// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";
import { registerERC721 } from "@latticexyz/world-modules/src/modules/erc721-puppet/registerERC721.sol";
import { ERC721MetadataData as MUDERC721MetadataData } from "@latticexyz/world-modules/src/modules/erc721-puppet/tables/ERC721Metadata.sol";
import { _erc721SystemId } from "@latticexyz/world-modules/src/modules/erc721-puppet/utils.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";

import { IWorld as IExperienceWorld } from "@biomesaw/experience/src/codegen/world/IWorld.sol";
import { ERC721MetadataData } from "@biomesaw/experience/src/codegen/tables/ERC721Metadata.sol";
import { PlayerObjectID, AirObjectID, DirtObjectID, ChestObjectID, SakuraLogObjectID, StoneObjectID, ChipObjectID, ChipBatteryObjectID, ForceFieldObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { IChip } from "../src/IChip.sol";

contract SetupScript is Script {
  function run(address worldAddress) external {
    IWorld world = IWorld(worldAddress);

    // Specify a store so that you can use tables directly in PostDeploy
    StoreSwitch.setStoreAddress(worldAddress);

    // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    // Start broadcasting transactions from the deployer account
    vm.startBroadcast(deployerPrivateKey);

    console.log("Using Chip contract at address: ");
    address chipAddress = Metadata.getChipAddress();
    console.logAddress(chipAddress);

    bytes32 chestEntityId = 0x000000000000000000000000000000000000000000000000000000000044ee46;
    uint8 buyObjectTypeId = ChipObjectID;
    uint256 buyPrice = 1e18;
    uint256 buyAmount = 99 * 12;
    address paymentToken = 0xE0aC150d02e4a9808403F94a289bcEc20d30A3fB;
    world.subpasschest__setupBuyShop(chestEntityId, buyObjectTypeId, buyPrice, buyAmount, paymentToken);

    vm.stopBroadcast();
  }
}
