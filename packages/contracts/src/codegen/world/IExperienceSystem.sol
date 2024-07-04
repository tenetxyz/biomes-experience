// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

/**
 * @title IExperienceSystem
 * @author MUD (https://mud.dev) by Lattice (https://lattice.xyz)
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface IExperienceSystem {
  function testexperience___canUnregister(address delegator) external returns (bool);

  function testexperience___onRegisterHook(
    address msgSender,
    ResourceId systemId,
    uint8 enabledHooksBitmap,
    bytes32 callDataHash
  ) external;

  function testexperience___onUnregisterHook(
    address msgSender,
    ResourceId systemId,
    uint8 enabledHooksBitmap,
    bytes32 callDataHash
  ) external;

  function testexperience___onBeforeCallSystem(address msgSender, ResourceId systemId, bytes memory callData) external;

  function testexperience___onAfterCallSystem(address msgSender, ResourceId systemId, bytes memory callData) external;
}
