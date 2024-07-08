// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ICustomUnregisterDelegation } from "@latticexyz/world/src/ICustomUnregisterDelegation.sol";
import { IOptionalSystemHook } from "@latticexyz/world/src/IOptionalSystemHook.sol";

import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { Build } from "@biomesaw/experience/src/utils/BuildUtils.sol";

interface IExperience is ICustomUnregisterDelegation, IOptionalSystemHook {
  function joinExperience() external payable;

  function getBiomeWorldAddress() external view returns (address);

  function create(string memory name, uint256 submissionPrice, Build memory blueprint) external;

  function submitBuilding(uint256 buildingId, VoxelCoord memory baseWorldCoord) external payable;

  function challengeBuilding(uint256 buildingId, uint256 n) external;
}
