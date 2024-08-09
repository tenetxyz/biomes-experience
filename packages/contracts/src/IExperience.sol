// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ICustomUnregisterDelegation } from "@latticexyz/world/src/ICustomUnregisterDelegation.sol";
import { IOptionalSystemHook } from "@latticexyz/world/src/IOptionalSystemHook.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { BuildWithPos } from "@biomesaw/experience/src/utils/BuildUtils.sol";

interface IExperience is ICustomUnregisterDelegation, IOptionalSystemHook {
  function joinExperience() external payable;

  function getBiomeWorldAddress() external view returns (address);

  function addAllowedPlayer(address player) external;

  function setGuardBuild(string memory name, BuildWithPos memory build) external;

  function setGuardPosition(VoxelCoord memory position) external;

  function setUnguardPosition(VoxelCoord[] memory positions) external;

  function hitIntruder(address intruder) external;

  function getIntruders() external view returns (address[] memory);
}
