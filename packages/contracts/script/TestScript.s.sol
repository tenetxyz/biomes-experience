// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IERC20Mintable } from "@latticexyz/world-modules/src/modules/erc20-puppet/IERC20Mintable.sol";
import { registerERC20 } from "@latticexyz/world-modules/src/modules/erc20-puppet/registerERC20.sol";
import { ERC20MetadataData as MUDERC20MetadataData } from "@latticexyz/world-modules/src/modules/erc20-puppet/tables/ERC20Metadata.sol";
import { _erc20SystemId, _metadataTableId } from "@latticexyz/world-modules/src/modules/erc20-puppet/utils.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";

import { IWorld as IExperienceWorld } from "@biomesaw/experience/src/codegen/world/IWorld.sol";
import { AllowedSetup } from "../src/codegen/tables/AllowedSetup.sol";
import { ERC20MetadataData } from "@biomesaw/experience/src/codegen/tables/ERC20Metadata.sol";

bytes14 constant BANK_TOKEN_NAMESPACE = "SUB";

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

    console.log("Deploying Bank token contract...");
    IERC20Mintable bankToken = registerERC20(
      world,
      BANK_TOKEN_NAMESPACE,
      MUDERC20MetadataData({ decimals: 18, name: "Settlers Union Bank Coin", symbol: "SUB" })
    );
    console.log("Deployed Bank token contract at address: ");
    address bankTokenAddress = address(bankToken);
    console.logAddress(bankTokenAddress);

    ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(BANK_TOKEN_NAMESPACE);

    IExperienceWorld(worldAddress).experience__setMUDTokenMetadata(
      namespaceId,
      ERC20MetadataData({
        creator: 0xA32EC0cc74FBdD0a7c2B7b654ca6B886000E2B65,
        decimals: 18,
        symbol: "SUB",
        name: "Settlers Union Bank Coin",
        description: "The Settlement Union's Bank chest mints SUB, backed 100:1 by the silver bars it possesses, and is used to purchase essential tools for cheap in their shops.",
        icon: "https://static.biomes.aw/sub-coin.png",
        systemId: _erc20SystemId(BANK_TOKEN_NAMESPACE)
      })
    );

    world.transferOwnership(namespaceId, chipAddress);

    chipAddress.call(abi.encodeWithSignature("setBankToken(address)", bankTokenAddress));
    chipAddress.call(abi.encodeWithSignature("addAllowedSetup(address)", 0xE0ae70caBb529336e25FA7a1f036b77ad0089d2a));
    chipAddress.call(abi.encodeWithSignature("addAllowedSetup(address)", 0xA32EC0cc74FBdD0a7c2B7b654ca6B886000E2B65));

    // console.logBool(
    //   AllowedSetup.get(0xE0ae70caBb529336e25FA7a1f036b77ad0089d2a)
    // );

    // chipAddress.call(abi.encodeWithSignature("renounceNamespaceOwnership(bytes32)", namespaceId));
    // console.log(ERC20Metadata.getName(_metadataTableId(BANK_TOKEN_NAMESPACE)));
    // ERC20Metadata.setName(_metadataTableId(BANK_TOKEN_NAMESPACE), "Settlers Union Bank Coin");

    vm.stopBroadcast();
  }
}
