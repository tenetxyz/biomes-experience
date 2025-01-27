// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

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
import { IDisplayChip } from "@biomesaw/world/src/prototypes/IDisplayChip.sol";

import { IWorld } from "@biomesaw/world/src/codegen/world/IWorld.sol";
import { VoxelCoord, VoxelCoordDirectionVonNeumann } from "@biomesaw/utils/src/Types.sol";
import { ChipOnTransferData, ChipOnPipeTransferData, TransferData } from "@biomesaw/world/src/Types.sol";
import { voxelCoordsAreEqual, inSurroundingCube } from "@biomesaw/utils/src/VoxelCoordUtils.sol";
import { getCallerNamespace } from "@biomesaw/utils/src/CallUtils.sol";
import { IWorld as IExperienceWorld } from "@biomesaw/experience/src/codegen/world/IWorld.sol";
import { ExperienceMetadata, ExperienceMetadataData } from "@biomesaw/experience/src/codegen/tables/ExperienceMetadata.sol";
import { ChipMetadata, ChipMetadataData } from "@biomesaw/experience/src/codegen/tables/ChipMetadata.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";
import { ChipAdmin } from "@biomesaw/experience/src/codegen/tables/ChipAdmin.sol";
import { ChipType, ResourceType } from "@biomesaw/experience/src/codegen/common.sol";

// Available utils, remove the ones you don't need
// See ObjectTypeIds.sol for all available object types
import { PlayerObjectID, AirObjectID, DirtObjectID, ChestObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { getBuildArgs, getMineArgs, getMoveArgs, getHitArgs, getDropArgs, getTransferArgs, getCraftArgs, getEquipArgs, getLoginArgs, getSpawnArgs } from "@biomesaw/experience/src/utils/HookUtils.sol";
import { getSystemId, isSystemId, callBuild, callMine, callMove, callHit, callDrop, callTransfer, callCraft, callEquip, callUnequip, callLogin, callLogout, callSpawn, callActivate } from "@biomesaw/experience/src/utils/DelegationUtils.sol";
import { hasBeforeAndAfterSystemHook, getObjectTypeAtCoord, getTerrainBlock, getEntityAtCoord, getPosition, getObjectType, getMiningDifficulty, getStackable, getDamage, getDurability, isTool, isBlock, getEntityFromPlayer, getPlayerFromEntity, getEquipped, getHealth, getStamina, getIsLoggedOff, getLastHitTime, getInventoryTool, getInventoryObjects, getNumInventoryObjects, getCount, getNumSlotsUsed, getNumUsesLeft, numMaxInChest } from "@biomesaw/experience/src/utils/EntityUtils.sol";
import { Area, insideArea, insideAreaIgnoreY, getEntitiesInArea, getArea } from "@biomesaw/experience/src/utils/AreaUtils.sol";
import { Build, BuildWithPos, buildExistsInWorld, buildWithPosExistsInWorld, getBuild, getBuildWithPos } from "@biomesaw/experience/src/utils/BuildUtils.sol";
import { weiToString, getEmptyBlockOnGround } from "@biomesaw/experience/src/utils/GameUtils.sol";
import { setExperienceMetadata, setJoinFee, deleteExperienceMetadata, setNotification, deleteNotifications, setStatus, deleteStatus, setRegisterMsg, deleteRegisterMsg, setUnregisterMsg, deleteUnregisterMsg, setNamespaceId, deleteNamespaceId, setAsset, deleteAsset } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setPlayers, pushPlayers, popPlayers, updatePlayers, deletePlayers, setArea, deleteArea, setBuild, deleteBuild, setBuildWithPos, deleteBuildWithPos, setCountdown, setCountdownEndTimestamp, setCountdownEndBlock, setTokenMetadata, deleteTokenMetadata, setNFTMetadata, setMUDNFTMetadata, deleteNFTMetadata } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setChipMetadata, deleteChipMetadata, setChipAttacher, deleteChipAttacher, setChipAdmin, deleteChipAdmin } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setExchanges, addExchange, deleteExchange, deleteExchanges, setExchangeInUnitAmount, setExchangeOutUnitAmount, setExchangeInMaxAmount, setExchangeOutMaxAmount, emitExchangeNotif, deleteExchangeNotif } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setPipeAccess, deletePipeAccess, deletePipeAccessList } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setSmartItemMetadata, setSmartItemName, setSmartItemDescription, deleteSmartItemMetadata, setGateApprovals, deleteGateApprovals, setGateApprovedPlayers, pushGateApprovedPlayer, popGateApprovedPlayer, updateGateApprovedPlayer, setGateApprovedNFT, pushGateApprovedNFT, popGateApprovedNFT, updateGateApprovedNFT } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { getForceField, getLatestChipData, isApprovedPlayer, hasApprovedNft, isApproved } from "@biomesaw/experience/src/utils/ForceFieldUtils.sol";
import { isApprovedPlayerForGate, hasApprovedNftForGate, isApprovedForGate } from "@biomesaw/experience/src/utils/GateUtils.sol";
import { encodeAddressExchangeResourceId, decodeAddressExchangeResourceId, encodeObjectExchangeResourceId, decodeObjectExchangeResourceId, exchangeExists } from "@biomesaw/experience/src/utils/ExchangeUtils.sol";
import { pipeAccessExists } from "@biomesaw/experience/src/utils/PipeUtils.sol";

import { CHIP_NAMESPACE, BUY_EXCHANGE_ID } from "./Constants.sol";
import { IChip } from "./IChip.sol";

import { AccessControl } from "@latticexyz/world/src/AccessControl.sol";
import { SmartItemMetadataData } from "@biomesaw/experience/src/codegen/tables/SmartItemMetadata.sol";
import { ExchangeInfo, ExchangeInfoData } from "@biomesaw/experience/src/codegen/tables/ExchangeInfo.sol";
import { ResourceType } from "@biomesaw/experience/src/codegen/common.sol";
import { ExchangeNotif, ExchangeNotifData } from "@biomesaw/experience/src/codegen/tables/ExchangeNotif.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { WorldResourceIdLib } from "@latticexyz/world/src/WorldResourceId.sol";
import { IERC721Mintable } from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";
import { ERC721Registry } from "@latticexyz/world-modules/src/modules/erc721-puppet/tables/ERC721Registry.sol";
import { ERC721_REGISTRY_TABLE_ID } from "@latticexyz/world-modules/src/modules/erc721-puppet/constants.sol";
import { registerERC721Strict } from "@latticexyz/world-modules/src/modules/erc721-puppet/registerERC721.sol";
import { ERC721MetadataData as MUDERC721MetadataData } from "@latticexyz/world-modules/src/modules/erc721-puppet/tables/ERC721Metadata.sol";
import { ERC721Metadata, ERC721MetadataData } from "@biomesaw/experience/src/codegen/tables/ERC721Metadata.sol";
import { _erc721SystemId } from "@latticexyz/world-modules/src/modules/erc721-puppet/utils.sol";
import { ShopNFT } from "./codegen/tables/ShopNFT.sol";
import { MintedNFT } from "./codegen/tables/MintedNFT.sol";
import { NFTMetadata, NFTMetadataData } from "./codegen/tables/NFTMetadata.sol";
import { OwnedNFTs } from "./codegen/tables/OwnedNFTs.sol";

contract Chip is IChip {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.Chest,
        name: "Mint NFT",
        description: "Mint players NFTs for depositing items"
      })
    );
    setNamespaceId(WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE));
  }

  modifier onlyChipNamespace() {
    require(getCallerNamespace(msg.sender) == CHIP_NAMESPACE, "Caller is not a system in the Chip namespace");
    _; // Continue execution
  }

  function adminTransferNamespaceOwnership(ResourceId namespaceId, address newOwner) public {
    AccessControl.requireOwner(WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE), msg.sender);
    IWorld(WorldContextConsumerLib._world()).transferOwnership(namespaceId, newOwner);
  }

  function changeAdmin(bytes32 entityId, address newAdmin) public onlyChipNamespace {
    setChipAdmin(entityId, newAdmin);
  }

  function setDisplayData(
    bytes32 chestEntityId,
    string memory name,
    string memory description
  ) public onlyChipNamespace {
    setSmartItemMetadata(chestEntityId, SmartItemMetadataData({ name: name, description: description }));
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
  ) public onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    require(ResourceId.unwrap(ShopNFT.getNftNamespaceId(chestEntityId)) == bytes32(0), "Shop already setup");

    IERC721Mintable shopNFT = registerERC721Strict(
      IWorld(WorldContextConsumerLib._world()),
      nftNamespace,
      MUDERC721MetadataData({ symbol: nftSymbol, name: nftName, baseURI: nftBaseUri })
    );
    address nftAddress = address(shopNFT);

    {
      ResourceId namespaceId = WorldResourceIdLib.encodeNamespace(nftNamespace);
      setMUDNFTMetadata(
        namespaceId,
        ERC721MetadataData({
          creator: admin,
          symbol: nftSymbol,
          name: nftName,
          description: nftDescription,
          baseURI: nftBaseUri,
          systemId: _erc721SystemId(nftNamespace)
        })
      );
      ShopNFT.set(chestEntityId, namespaceId);
      NFTMetadata.set(nftAddress, admin, buyObjectTypeId, buyAmount, 0);
      OwnedNFTs.push(admin, nftAddress);
    }

    addExchange(
      chestEntityId,
      BUY_EXCHANGE_ID,
      ExchangeInfoData({
        inResourceType: ResourceType.Object,
        inResourceId: encodeObjectExchangeResourceId(buyObjectTypeId),
        inUnitAmount: buyAmount,
        inMaxAmount: type(uint256).max,
        outResourceType: ResourceType.ERC721,
        outResourceId: encodeAddressExchangeResourceId(nftAddress),
        outUnitAmount: 1,
        outMaxAmount: type(uint256).max
      })
    );
  }

  function setupBuyShopExistingNFT(bytes32 chestEntityId, ResourceId nftNamespaceId) public onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    require(ResourceId.unwrap(ShopNFT.getNftNamespaceId(chestEntityId)) == bytes32(0), "Shop already setup");
    AccessControl.requireOwner(nftNamespaceId, address(this));
    address nftAddress = ERC721Registry.get(ERC721_REGISTRY_TABLE_ID, nftNamespaceId);
    require(nftAddress != address(0), "Pass not registered");
    NFTMetadataData memory nftMetadata = NFTMetadata.get(nftAddress);
    require(nftMetadata.owner == admin, "You can only use passes that you created");
    uint8 buyObjectTypeId = nftMetadata.objectTypeId;
    require(buyObjectTypeId != NullObjectTypeId, "Pass not setup");
    uint256 buyAmount = nftMetadata.objectAmount;

    ShopNFT.set(chestEntityId, nftNamespaceId);

    addExchange(
      chestEntityId,
      BUY_EXCHANGE_ID,
      ExchangeInfoData({
        inResourceType: ResourceType.Object,
        inResourceId: encodeObjectExchangeResourceId(buyObjectTypeId),
        inUnitAmount: buyAmount,
        inMaxAmount: type(uint256).max,
        outResourceType: ResourceType.ERC721,
        outResourceId: encodeAddressExchangeResourceId(nftAddress),
        outUnitAmount: 1,
        outMaxAmount: type(uint256).max
      })
    );
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IChestChip).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function onAttached(
    bytes32 callerEntityId,
    bytes32 targetEntityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address player = getPlayerFromEntity(callerEntityId);
    setChipAttacher(targetEntityId, player);
    setChipAdmin(targetEntityId, player);
    require(getNumInventoryObjects(targetEntityId) == 0, "Chest must be empty");
    return true;
  }

  function onDetached(
    bytes32 callerEntityId,
    bytes32 targetEntityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address admin = ChipAdmin.get(targetEntityId);
    address player = getPlayerFromEntity(callerEntityId);

    ResourceId namespaceId = ShopNFT.getNftNamespaceId(targetEntityId);
    if (ResourceId.unwrap(namespaceId) != bytes32(0)) {
      ShopNFT.deleteRecord(targetEntityId);
    }
    deleteExchanges(targetEntityId);

    deleteSmartItemMetadata(targetEntityId);
    deleteChipAttacher(targetEntityId);
    deleteChipAdmin(targetEntityId);
    return admin == player;
  }

  function onPowered(
    bytes32 callerEntityId,
    bytes32 targetEntityId,
    uint16 numBattery
  ) public override onlyBiomeWorld {}

  function onChipHit(bytes32 callerEntityId, bytes32 targetEntityId) public override onlyBiomeWorld {}

  function onTransfer(ChipOnTransferData memory transferContext) public payable override onlyBiomeWorld returns (bool) {
    address admin = ChipAdmin.get(transferContext.targetEntityId);
    require(admin != address(0), "Chest is not setup");
    address player = getPlayerFromEntity(transferContext.callerEntityId);
    require(
      ResourceId.unwrap(ShopNFT.getNftNamespaceId(transferContext.targetEntityId)) != bytes32(0),
      "Shop not setup"
    );
    ExchangeInfoData memory exchangeInfo = ExchangeInfo.get(transferContext.targetEntityId, BUY_EXCHANGE_ID);
    uint8 exchangeObjectTypeId = decodeObjectExchangeResourceId(exchangeInfo.inResourceId);
    if (exchangeObjectTypeId != transferContext.transferData.objectTypeId) {
      return false;
    }
    for (uint i = 0; i < transferContext.transferData.toolEntityIds.length; i++) {
      require(
        getNumUsesLeft(transferContext.transferData.toolEntityIds[i]) == getDurability(exchangeObjectTypeId),
        "Tool must have full durability"
      );
    }

    if (player == admin) {
      if (!transferContext.isDeposit) {
        return true;
      }
    }

    if (transferContext.isDeposit) {
      require(transferContext.transferData.numToTransfer == exchangeInfo.inUnitAmount, "Invalid amount of items");
      address nftAddress = decodeAddressExchangeResourceId(exchangeInfo.outResourceId);
      require(!MintedNFT.getMinted(player, nftAddress), "Player has already minted the pass");
      uint256 nextTokenId = NFTMetadata.getNftNextTokenId(nftAddress) + 1;
      NFTMetadata.setNftNextTokenId(nftAddress, nextTokenId);
      MintedNFT.setMinted(player, nftAddress, true);

      string memory nftName = ERC721Metadata.getName(nftAddress);

      IERC721Mintable(nftAddress).safeMint(player, nextTokenId);
      setNotification(player, string.concat("You've earned the ", nftName, " pass!"));
    } else {
      revert("Only the admin can withdraw items");
    }

    emitExchangeNotif(
      transferContext.targetEntityId,
      ExchangeNotifData({
        player: player,
        inResourceType: exchangeInfo.inResourceType,
        inResourceId: exchangeInfo.inResourceId,
        inAmount: transferContext.transferData.numToTransfer,
        outResourceType: exchangeInfo.outResourceType,
        outResourceId: exchangeInfo.outResourceId,
        outAmount: 1
      })
    );

    return true;
  }

  function onPipeTransfer(
    ChipOnPipeTransferData memory transferContext
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    return false;
  }

  receive() external payable {
    // This function is executed when a contract receives plain Ether (without data)
  }
}
