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
import { Exchange, ExchangeData } from "../src/codegen/tables/Exchange.sol";

import { CoalOreObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { ERC20MetadataData } from "@biomesaw/experience/src/codegen/tables/ERC20Metadata.sol";
import { setTokens } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";

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

    uint8 objectTypeId = CoalOreObjectID;
    console.log("Exchange Data for Object");
    console.logUint(objectTypeId);
    console.log("Price");
    console.logUint(Exchange.getPrice(objectTypeId));
    console.log("Last Purchase Time");
    console.logUint(Exchange.getLastPurchaseTime(objectTypeId));
    console.log("Sold");
    console.logUint(Exchange.getSold(objectTypeId));

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
        creator: 0xE0ae70caBb529336e25FA7a1f036b77ad0089d2a,
        decimals: 18,
        symbol: "SUB",
        name: "Settlers Union Bank Coin",
        description: "The Settlement Union's Bank chest mints SUB, backed 100:1 by the silver bars it possesses, and is used to purchase essential tools for cheap in their shops.",
        icon: "https://static.biomes.aw/sub-coin.png",
        systemId: _erc20SystemId(BANK_TOKEN_NAMESPACE)
      })
    );

    bankToken.mint(0xE0ae70caBb529336e25FA7a1f036b77ad0089d2a, 50000e18);
    bankToken.mint(0x1B1240e0c3F3D4EB227916aB2BEb86E01C85d48f, 100e18);

    address[] memory tokens = new address[](1);
    tokens[0] = bankTokenAddress;
    setTokens(tokens);

    vm.stopBroadcast();
  }
}
