// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { WorldContextConsumerLib } from "@latticexyz/world/src/WorldContext.sol";
import { ResourceId, WorldResourceIdLib, WorldResourceIdInstance } from "@latticexyz/world/src/WorldResourceId.sol";
import { Hook } from "@latticexyz/store/src/Hook.sol";
import { IERC165 } from "@latticexyz/world/src/IERC165.sol";
import { ICustomUnregisterDelegation } from "@latticexyz/world/src/ICustomUnregisterDelegation.sol";
import { IOptionalSystemHook } from "@latticexyz/world/src/IOptionalSystemHook.sol";
import { BEFORE_CALL_SYSTEM, AFTER_CALL_SYSTEM, ALL } from "@latticexyz/world/src/systemHookTypes.sol";
import { RESOURCE_SYSTEM } from "@latticexyz/world/src/worldResourceTypes.sol";
import { OptionalSystemHooks } from "@latticexyz/world/src/codegen/tables/OptionalSystemHooks.sol";
import { IChestChip } from "@biomesaw/world/src/prototypes/IChestChip.sol";
import { IForceFieldChip } from "@biomesaw/world/src/prototypes/IForceFieldChip.sol";

import { IWorld } from "@biomesaw/world/src/codegen/world/IWorld.sol";
import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { voxelCoordsAreEqual, inSurroundingCube } from "@biomesaw/utils/src/VoxelCoordUtils.sol";
import { IWorld as IExperienceWorld } from "@biomesaw/experience/src/codegen/world/IWorld.sol";
import { ExperienceMetadata, ExperienceMetadataData } from "@biomesaw/experience/src/codegen/tables/ExperienceMetadata.sol";
import { ChipMetadata, ChipMetadataData } from "@biomesaw/experience/src/codegen/tables/ChipMetadata.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";
import { ChipType } from "@biomesaw/experience/src/codegen/common.sol";
import { ShopType, ShopTxType } from "@biomesaw/experience/src/codegen/common.sol";

// Available utils, remove the ones you don't need
// See ObjectTypeIds.sol for all available object types
import { PlayerObjectID, AirObjectID, DirtObjectID, ChestObjectID, StoneObjectID, SakuraLogObjectID, ChipObjectID, ChipBatteryObjectID, ForceFieldObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { getBuildArgs, getMineArgs, getMoveArgs, getHitArgs, getDropArgs, getTransferArgs, getCraftArgs, getEquipArgs, getLoginArgs, getSpawnArgs } from "@biomesaw/experience/src/utils/HookUtils.sol";
import { getSystemId, isSystemId, callBuild, callMine, callMove, callHit, callDrop, callTransfer, callCraft, callEquip, callUnequip, callLogin, callLogout, callSpawn, callActivate } from "@biomesaw/experience/src/utils/DelegationUtils.sol";
import { hasBeforeAndAfterSystemHook, getObjectTypeAtCoord, getTerrainBlock, getEntityAtCoord, getPosition, getObjectType, getMiningDifficulty, getStackable, getDamage, getDurability, isTool, isBlock, getEntityFromPlayer, getPlayerFromEntity, getEquipped, getHealth, getStamina, getIsLoggedOff, getLastHitTime, getInventoryTool, getInventoryObjects, getNumInventoryObjects, getCount, getNumSlotsUsed, getNumUsesLeft } from "@biomesaw/experience/src/utils/EntityUtils.sol";
import { Area, insideArea, insideAreaIgnoreY, getEntitiesInArea, getArea } from "@biomesaw/experience/src/utils/AreaUtils.sol";
import { Build, BuildWithPos, buildExistsInWorld, buildWithPosExistsInWorld, getBuild, getBuildWithPos } from "@biomesaw/experience/src/utils/BuildUtils.sol";
import { weiToString, getEmptyBlockOnGround } from "@biomesaw/experience/src/utils/GameUtils.sol";
import { setExperienceMetadata, setJoinFee, deleteExperienceMetadata, setNotification, deleteNotifications, setStatus, deleteStatus, setRegisterMsg, deleteRegisterMsg, setUnregisterMsg, deleteUnregisterMsg } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setPlayers, pushPlayers, popPlayers, updatePlayers, deletePlayers, setArea, deleteArea, setBuild, deleteBuild, setBuildWithPos, deleteBuildWithPos, setCountdown, setCountdownEndTimestamp, setCountdownEndBlock, setTokenMetadata, deleteTokenMetadata, setNFTMetadata, deleteNFTMetadata, setTokens, pushTokens, popTokens, updateTokens, deleteTokens, setNfts, pushNfts, popNfts, updateNfts, deleteNfts } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setChipMetadata, deleteChipMetadata, setChipAttacher, deleteChipAttacher } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setShop, deleteShop, setBuyShop, setSellShop, setShopBalance, setBuyPrice, setSellPrice, setShopObjectTypeId, emitShopNotif, deleteShopNotif } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setChestMetadata, setChestName, setChestDescription, deleteChestMetadata, setForceFieldMetadata, setForceFieldName, setForceFieldDescription, deleteForceFieldMetadata, setForceFieldApprovals, deleteForceFieldApprovals, setFFApprovedPlayers, pushFFApprovedPlayer, popFFApprovedPlayer, updateFFApprovedPlayer, setFFApprovedNFT, pushFFApprovedNFT, popFFApprovedNFT, updateFFApprovedNFT } from "@biomesaw/experience/src/utils/ChipUtils.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { ItemShop, ItemShopData } from "@biomesaw/experience/src/codegen/tables/ItemShop.sol";
import { ChestMetadataData } from "@biomesaw/experience/src/codegen/tables/ChestMetadata.sol";
import { ShopType } from "@biomesaw/experience/src/codegen/common.sol";
import { ItemShopNotifData } from "@biomesaw/experience/src/codegen/tables/ItemShopNotif.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { ShopMetadata } from "./codegen/tables/ShopMetadata.sol";
import { AllowedSetup } from "./codegen/tables/AllowedSetup.sol";
import { MintedNFT } from "./codegen/tables/MintedNFT.sol";
import { SoldObject } from "./codegen/tables/SoldObject.sol";
import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";

contract Chip is IChestChip, Ownable {
  constructor(address _biomeWorldAddress) Ownable(msg.sender) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);
  }

  function setDisplayData(bytes32 chestEntityId, string memory name, string memory description) public {
    require(
      ChipAttachment.getAttacher(chestEntityId) == msg.sender,
      "Only the attacher can set the chest display data"
    );
    setChestMetadata(chestEntityId, ChestMetadataData({ name: name, description: description }));
  }

  function renounceNamespaceOwnership(ResourceId namespaceId) public onlyOwner {
    IWorld(WorldContextConsumerLib._world()).transferOwnership(namespaceId, _msgSender());
  }

  function addAllowedSetup(address attacher) public onlyOwner {
    AllowedSetup.set(attacher, true);
  }

  function setShopNFT(address nftAddres) public onlyOwner {
    address[] memory nfts = new address[](1);
    nfts[0] = nftAddres;
    setNfts(nfts);
    ShopMetadata.setShopNFT(nftAddres);
    ShopMetadata.setShopNFTNextTokenId(0);
  }

  // function hasBought(address player, uint8 objectTypeId) public view returns (bool) {
  //   return BoughtObject.getBought(player, objectTypeId);
  // }

  function getShopNFT() public view returns (address) {
    return ShopMetadata.getShopNFT();
  }

  function setupBuyShop(
    bytes32 chestEntityId,
    uint8 buyObjectTypeId,
    uint256 buyPrice,
    uint256 buyAmount,
    address paymentToken
  ) public payable {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can set up the shop");
    require(ItemShop.getObjectTypeId(chestEntityId) == NullObjectTypeId, "Chest already has a shop");

    setBuyShop(chestEntityId, buyObjectTypeId, buyPrice, paymentToken);

    uint256 addingBalance = buyPrice * buyAmount;
    uint256 newBalance = ItemShop.getBalance(chestEntityId) + addingBalance;
    setShopBalance(chestEntityId, newBalance);

    // if (paymentToken == address(0)) {
    //   require(msg.value == addingBalance, "Insufficient Ether sent");
    // } else {
    //   IERC20 token = IERC20(paymentToken);
    //   require(token.transferFrom(msg.sender, address(this), addingBalance), "Failed to transfer tokens");
    // }
  }

  function destroyShop(bytes32 chestEntityId, uint8 objectTypeId) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can destroy the chest");
    require(ItemShop.getObjectTypeId(chestEntityId) == objectTypeId, "Chest is not set up");
    deleteChestMetadata(chestEntityId);

    deleteShop(chestEntityId);
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IChestChip).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function onAttached(
    bytes32 playerEntityId,
    bytes32 entityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    require(getNumInventoryObjects(entityId) == 0, "Chest must be empty");
    address player = getPlayerFromEntity(playerEntityId);
    setChipAttacher(entityId, player);

    address nftAddress = ShopMetadata.getShopNFT();
    require(nftAddress != address(0), "NFT address cannot be 0");

    return AllowedSetup.get(player);
  }

  function onDetached(
    bytes32 playerEntityId,
    bytes32 entityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address owner = ChipAttachment.getAttacher(entityId);
    address player = getPlayerFromEntity(playerEntityId);
    deleteChestMetadata(entityId);

    if (ItemShop.getObjectTypeId(entityId) != NullObjectTypeId) {
      // Clear existing shop data
      deleteShop(entityId);
    }

    deleteChipAttacher(entityId);
    return owner == player;
  }

  function onPowered(bytes32 playerEntityId, bytes32 entityId, uint16 numBattery) public override onlyBiomeWorld {}

  function onChipHit(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {}

  function onTransfer(
    bytes32 srcEntityId,
    bytes32 dstEntityId,
    uint8 transferObjectTypeId,
    uint16 numToTransfer,
    bytes32[] memory toolEntityIds,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool) {
    bool isDeposit = getObjectType(srcEntityId) == PlayerObjectID;
    bytes32 chestEntityId = isDeposit ? dstEntityId : srcEntityId;
    address owner = ChipAttachment.getAttacher(chestEntityId);
    require(owner != address(0), "Chest does not exist");
    address player = getPlayerFromEntity(isDeposit ? srcEntityId : dstEntityId);
    if (player == owner) {
      return true;
    }

    ItemShopData memory chestShopData = ItemShop.get(chestEntityId);
    if (chestShopData.objectTypeId != transferObjectTypeId) {
      return false;
    }
    for (uint i = 0; i < toolEntityIds.length; i++) {
      require(
        getNumUsesLeft(toolEntityIds[i]) != getDurability(chestShopData.objectTypeId),
        "Tool must have full durability"
      );
    }

    address nftAddress = ShopMetadata.getShopNFT();
    require(nftAddress != address(0), "NFT not set up");

    if (isDeposit) {
      uint256 newNumSold = SoldObject.getNumSold(player, transferObjectTypeId);
      newNumSold += numToTransfer;
      SoldObject.setNumSold(player, transferObjectTypeId, newNumSold);
      if (transferObjectTypeId == SakuraLogObjectID && newNumSold >= 5 && !MintedNFT.getMinted(player)) {
        uint256 nextTokenId = ShopMetadata.getShopNFTNextTokenId() + 1;
        IERC721Mintable(nftAddress).safeMint(player, nextTokenId);
        ShopMetadata.setShopNFTNextTokenId(nextTokenId);
        MintedNFT.setMinted(player, true);

        emitShopNotif(
          chestEntityId,
          ItemShopNotifData({
            player: player,
            shopTxType: ShopTxType.Sell,
            objectTypeId: chestShopData.objectTypeId,
            price: 1,
            amount: numToTransfer,
            paymentToken: nftAddress
          })
        );
      }
    } else {
      revert("Cannot buy from chest");
    }

    emitShopNotif(
      chestEntityId,
      ItemShopNotifData({
        player: player,
        shopTxType: isDeposit ? ShopTxType.Sell : ShopTxType.Buy,
        objectTypeId: chestShopData.objectTypeId,
        price: numToTransfer * (isDeposit ? chestShopData.buyPrice : chestShopData.sellPrice),
        amount: numToTransfer,
        paymentToken: chestShopData.paymentToken
      })
    );

    return true;
  }
}
