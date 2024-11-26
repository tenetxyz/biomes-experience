// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { System } from "@latticexyz/world/src/System.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";

import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { AccessControlLib } from "@latticexyz/world-modules/src/utils/AccessControlLib.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { AllowedSetup } from "./codegen/tables/AllowedSetup.sol";
import { ShopMetadata } from "./codegen/tables/ShopMetadata.sol";
import { BoughtObject } from "./codegen/tables/BoughtObject.sol";

import { IWorld } from "./codegen/world/IWorld.sol";
import { CHIP_NAMESPACE } from "./Constants.sol";
import { IChip } from "./IChip.sol";

contract ChipSystem is System {
  function getChipContract() internal view returns (IChip) {
    return IChip(Metadata.getChipAddress());
  }

  function onlyAttacher(bytes32 entityId) internal view {
    require(ChipAttachment.getAttacher(entityId) == _msgSender(), "Only the attacher can call this function");
  }

  function setShopNFT(address nftAddres) public {
    AccessControlLib.requireOwner(WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE), _msgSender());
    IChip chip = getChipContract();
    chip.setShopNFT(nftAddres);
  }

  function addAllowedSetup(address attacher) public {
    AccessControlLib.requireOwner(WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE), _msgSender());
    AllowedSetup.set(attacher, true);
  }

  function setDisplayData(bytes32 entityId, string memory name, string memory description) public {
    onlyAttacher(entityId);
    IChip chip = getChipContract();
    chip.setDisplayData(entityId, name, description);
  }

  function setupBuyShop(
    bytes32 chestEntityId,
    uint8 buyObjectTypeId,
    uint256 buyPrice,
    uint256 buyAmount,
    address paymentToken
  ) public payable {
    onlyAttacher(chestEntityId);
    IChip chip = getChipContract();
    IWorld(_world()).transferBalanceToAddress(
      WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE),
      address(this),
      _msgValue()
    );
    chip.setupBuyShop{ value: _msgValue() }(chestEntityId, buyObjectTypeId, buyPrice, buyAmount, paymentToken);
  }

  function destroyShop(bytes32 chestEntityId, uint8 objectTypeId) public {
    onlyAttacher(chestEntityId);
    IChip chip = getChipContract();
    chip.destroyShop(chestEntityId, objectTypeId);
  }

  function getShopNFT() public view returns (address) {
    return ShopMetadata.getShopNFT();
  }

  function hasBought(address player, uint8 objectTypeId) public view returns (bool) {
    return BoughtObject.getBought(player, objectTypeId);
  }

  receive() external payable {
    // This function is executed when a contract receives plain Ether (without data)
  }
}
