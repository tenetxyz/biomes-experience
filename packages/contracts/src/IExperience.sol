// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ICustomUnregisterDelegation } from "@latticexyz/world/src/ICustomUnregisterDelegation.sol";
import { IOptionalSystemHook } from "@latticexyz/world/src/IOptionalSystemHook.sol";
import { Area } from "@biomesaw/experience/src/utils/AreaUtils.sol";

interface IExperience is ICustomUnregisterDelegation, IOptionalSystemHook {
  function joinExperience() external payable;

  function setupGame(string memory name, Area memory area) external payable;

  function getBiomeWorldAddress() external view returns (address);
}
