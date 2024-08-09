// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";
import { setPlayers, pushPlayers, popPlayers, updatePlayers, deletePlayers, setArea, deleteArea, setBuild, deleteBuild, setBuildWithPos, deleteBuildWithPos, setCountdown, setCountdownEndTimestamp, setCountdownEndBlock, setTokens, pushTokens, popTokens, updateTokens, deleteTokens, setNfts, pushNfts, popNfts, updateNfts, deleteNfts } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";

import { ShopToken } from "../src/ShopToken.sol";
import { AllowedSetup } from "../src/codegen/tables/AllowedSetup.sol";

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

    console.log("Deploying Bank ShopToken contract...");
    ShopToken bankToken = new ShopToken("Settlers Union Bank Note", "SUB", chipAddress);
    console.log("Deployed Bank ShopToken contract at address: ");
    address bankTokenAddress = address(bankToken);
    console.logAddress(bankTokenAddress);
    pushTokens(bankTokenAddress);

    // address bankTokenAddress = 0x82722839933E813936480CD36bAa2617215ACa34;
    bankTokenAddress.call(
      abi.encodeWithSignature("addAllowedSetup(address)", 0xE0ae70caBb529336e25FA7a1f036b77ad0089d2a)
    );

    // console.logBool(
    //   AllowedSetup.get(0x0f5D1ef48f12b6f691401bfe88c2037c690a6afe, 0xE0ae70caBb529336e25FA7a1f036b77ad0089d2a)
    // );

    vm.stopBroadcast();
  }
}
