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
import { Fees } from "../src/codegen/tables/Fees.sol";

import { IWorld as IExperienceWorld } from "@biomesaw/experience/src/codegen/world/IWorld.sol";
import { ERC721MetadataData } from "@biomesaw/experience/src/codegen/tables/ERC721Metadata.sol";

bytes14 constant SHOP_NFT_NAMESPACE = "PSUB";

contract TestScript is Script {
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

    console.log("Deploying Shop NFT contract...");
    IERC721Mintable shopNFT = registerERC721(
      world,
      SHOP_NFT_NAMESPACE,
      MUDERC721MetadataData({
        symbol: "PSUB",
        name: "Settlers Union Bank Pass",
        baseURI: "https://static.biomes.aw/sub-logo.png"
      })
    );
    console.log("Deployed Shop NFT contract at address: ");
    address shopNFTAddress = address(shopNFT);
    console.logAddress(shopNFTAddress);

    ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(SHOP_NFT_NAMESPACE);

    IExperienceWorld(worldAddress).experience__setMUDNFTMetadata(
      namespaceId,
      ERC721MetadataData({
        creator: 0xA32EC0cc74FBdD0a7c2B7b654ca6B886000E2B65,
        symbol: "PSUB",
        name: "Settlers Union Bank Pass",
        description: "The Settlement Union's Bank pass allows you to access the bank's services.",
        baseURI: "https://static.biomes.aw/sub-logo.png",
        systemId: _erc721SystemId(SHOP_NFT_NAMESPACE)
      })
    );

    world.transferOwnership(namespaceId, chipAddress);

    chipAddress.call(abi.encodeWithSignature("setShopNFT(address)", shopNFTAddress));
    chipAddress.call(abi.encodeWithSignature("addAllowedSetup(address)", 0xE0ae70caBb529336e25FA7a1f036b77ad0089d2a));
    chipAddress.call(abi.encodeWithSignature("addAllowedSetup(address)", 0xA32EC0cc74FBdD0a7c2B7b654ca6B886000E2B65));

    vm.stopBroadcast();
  }
}
