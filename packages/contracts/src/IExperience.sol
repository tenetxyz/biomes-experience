// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ICustomUnregisterDelegation } from "@latticexyz/world/src/ICustomUnregisterDelegation.sol";
import { IOptionalSystemHook } from "@latticexyz/world/src/IOptionalSystemHook.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";

interface IExperience is ICustomUnregisterDelegation, IOptionalSystemHook {
  function joinExperience() external payable;

  function getBiomeWorldAddress() external view returns (address);

  function setVaultChestCoord(VoxelCoord memory vaultChestCoord) external;

  function withdraw(uint8 objectTypeId, uint16 numToWithdraw, bytes32 withdrawChestEntityId) external;

  function withdrawTool(bytes32 toolEntityId, bytes32 withdrawChestEntityId) external;
}
