// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { IChestChip } from "@biomesaw/world/src/prototypes/IChestChip.sol";
import { IForceFieldChip } from "@biomesaw/world/src/prototypes/IForceFieldChip.sol";
import { IDisplayChip } from "@biomesaw/world/src/prototypes/IDisplayChip.sol";

interface IChip is IChestChip {
  function changeAdmin(bytes32 entityId, address newAdmin) external;

  function setDisplayData(bytes32 entityId, string memory name, string memory description) external;

  function configurePipeAccess(
    bytes32 chestEntityId,
    bytes32 callerEntityId,
    bool depositAllowed,
    bool withdrawAllowed
  ) external;
}
