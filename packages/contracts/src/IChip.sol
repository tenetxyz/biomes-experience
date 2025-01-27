// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { ResourceId } from "@latticexyz/world/src/WorldResourceId.sol";

import { IChestChip } from "@biomesaw/world/src/prototypes/IChestChip.sol";
import { IForceFieldChip } from "@biomesaw/world/src/prototypes/IForceFieldChip.sol";
import { IDisplayChip } from "@biomesaw/world/src/prototypes/IDisplayChip.sol";

interface IChip is IChestChip {
  function changeAdmin(bytes32 entityId, address newAdmin) external;

  function setDisplayData(bytes32 entityId, string memory name, string memory description) external;

  function setupBuyShop(
    bytes32 chestEntityId,
    uint8 buyObjectTypeId,
    uint256 buyAmount,
    string memory nftSymbol,
    string memory nftName,
    string memory nftDescription,
    string memory nftBaseUri,
    bytes14 nftNamespace
  ) external;

  function setupBuyShopExistingNFT(bytes32 chestEntityId, ResourceId nftNamespaceId) external;

  function adminTransferNamespaceOwnership(ResourceId namespaceId, address newOwner) external;
}
