// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAdmin } from "@biomesaw/experience/src/codegen/tables/ChipAdmin.sol";
import { ResourceId, WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IWorld } from "./codegen/world/IWorld.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { CHIP_NAMESPACE } from "./Constants.sol";
import { IChip } from "./IChip.sol";
import { NFTMetadata, NFTMetadataData } from "./codegen/tables/NFTMetadata.sol";
import { OwnedNFTs } from "./codegen/tables/OwnedNFTs.sol";

contract ChipSystem is System {
  function getChipContract() internal view returns (IChip) {
    return IChip(Metadata.getChipAddress());
  }

  function onlyAdmin(bytes32 entityId) internal view {
    require(ChipAdmin.get(entityId) == _msgSender(), "Only the admin can call this function");
  }

  function changeAdmin(bytes32 entityId, address newAdmin) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.changeAdmin(entityId, newAdmin);
    changeAllNFTsOwner(newAdmin);
  }

  function changeAllNFTsOwner(address newOwner) public {
    address[] memory nfts = OwnedNFTs.get(_msgSender());
    for (uint256 i = 0; i < nfts.length; i++) {
      changeNFTOwner(nfts[i], newOwner);
    }
  }

  function changeNFTOwner(address nftAddress, address newOwner) public {
    require(NFTMetadata.getOwner(nftAddress) == _msgSender(), "Only the owner can change the owner");
    NFTMetadata.setOwner(nftAddress, newOwner);
  }

  function setDisplayData(bytes32 entityId, string memory name, string memory description) public {
    onlyAdmin(entityId);
    IChip chip = getChipContract();
    chip.setDisplayData(entityId, name, description);
  }

  function setupBuyShop(
    bytes32 chestEntityId,
    uint8 buyObjectTypeId,
    uint256 buyAmount,
    string memory nftSymbol,
    string memory nftName,
    string memory nftDescription,
    string memory nftBaseUri,
    bytes14 nftNamespace
  ) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    chip.setupBuyShop(
      chestEntityId,
      buyObjectTypeId,
      buyAmount,
      nftSymbol,
      nftName,
      nftDescription,
      nftBaseUri,
      nftNamespace
    );
  }

  function setupBuyShopExistingNFT(bytes32 chestEntityId, ResourceId nftNamespaceId) public {
    onlyAdmin(chestEntityId);
    IChip chip = getChipContract();
    chip.setupBuyShopExistingNFT(chestEntityId, nftNamespaceId);
  }

  receive() external payable {
    // This function is executed when a contract receives plain Ether (without data)
  }
}
