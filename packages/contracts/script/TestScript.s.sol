// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";

import { IWorld } from "../src/codegen/world/IWorld.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Metadata } from "../src/codegen/tables/Metadata.sol";
import { Fees } from "../src/codegen/tables/Fees.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    address tokenAddress = 0x1275D096B9DBf2347bD2a131Fb6BDaB0B4882487;

    console.logUint(Fees.get(chipAddress));
    console.logUint(Fees.get(tokenAddress));
    console.logUint(IERC20(tokenAddress).balanceOf(0x70997970C51812dc3A010C7d01b50e0d17dc79C8));

    // chipAddress.call(abi.encodeWithSignature("withdrawFees(address)", tokenAddress));

    vm.stopBroadcast();
  }
}
