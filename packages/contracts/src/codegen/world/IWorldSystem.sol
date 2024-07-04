// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

/**
 * @title IWorldSystem
 * @author MUD (https://mud.dev) by Lattice (https://lattice.xyz)
 * @dev This interface is automatically generated from the corresponding system contract. Do not edit manually.
 */
interface IWorldSystem {
  function testexperience__supportsInterface(bytes4 interfaceId) external pure returns (bool);

  function testexperience__canUnregister(address delegator) external returns (bool);

  function testexperience__onRegisterHook(
    address msgSender,
    ResourceId systemId,
    uint8 enabledHooksBitmap,
    bytes32 callDataHash
  ) external;

  function testexperience__onUnregisterHook(
    address msgSender,
    ResourceId systemId,
    uint8 enabledHooksBitmap,
    bytes32 callDataHash
  ) external;

  function testexperience__onBeforeCallSystem(address msgSender, ResourceId systemId, bytes memory callData) external;

  function testexperience__onAfterCallSystem(address msgSender, ResourceId systemId, bytes memory callData) external;
}
