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
import { IChip } from "@biomesaw/world/src/prototypes/IChip.sol";

import { IWorld } from "@biomesaw/world/src/codegen/world/IWorld.sol";
import { VoxelCoord } from "@biomesaw/utils/src/Types.sol";
import { voxelCoordsAreEqual, inSurroundingCube } from "@biomesaw/utils/src/VoxelCoordUtils.sol";
import { IWorld as IExperienceWorld } from "@biomesaw/experience/src/codegen/world/IWorld.sol";
import { ExperienceMetadata, ExperienceMetadataData } from "@biomesaw/experience/src/codegen/tables/ExperienceMetadata.sol";
import { ChipMetadata, ChipMetadataData } from "@biomesaw/experience/src/codegen/tables/ChipMetadata.sol";
import { ChipType } from "@biomesaw/experience/src/codegen/common.sol";

// Available utils, remove the ones you don't need
// See ObjectTypeIds.sol for all available object types
import { PlayerObjectID, AirObjectID, DirtObjectID, ChestObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { getBuildArgs, getMineArgs, getMoveArgs, getHitArgs, getDropArgs, getTransferArgs, getCraftArgs, getEquipArgs, getLoginArgs, getSpawnArgs } from "@biomesaw/experience/src/utils/HookUtils.sol";
import { getSystemId, isSystemId, callBuild, callMine, callMove, callHit, callDrop, callTransfer, callCraft, callEquip, callUnequip, callLogin, callLogout, callSpawn, callActivate } from "@biomesaw/experience/src/utils/DelegationUtils.sol";
import { hasBeforeAndAfterSystemHook, getObjectTypeAtCoord, getTerrainBlock, getEntityAtCoord, getPosition, getObjectType, getMiningDifficulty, getStackable, getDamage, getDurability, isTool, isBlock, getEntityFromPlayer, getPlayerFromEntity, getEquipped, getHealth, getStamina, getIsLoggedOff, getLastHitTime, getInventoryTool, getInventoryObjects, getCount, getNumSlotsUsed, getNumUsesLeft } from "@biomesaw/experience/src/utils/EntityUtils.sol";
import { Area, insideArea, insideAreaIgnoreY, getEntitiesInArea, getArea } from "@biomesaw/experience/src/utils/AreaUtils.sol";
import { Build, BuildWithPos, buildExistsInWorld, buildWithPosExistsInWorld, getBuild, getBuildWithPos } from "@biomesaw/experience/src/utils/BuildUtils.sol";
import { weiToString, getEmptyBlockOnGround } from "@biomesaw/experience/src/utils/GameUtils.sol";
import { setExperienceMetadata, setJoinFee, deleteExperienceMetadata, setNotification, deleteNotifications, setStatus, deleteStatus, setRegisterMsg, deleteRegisterMsg, setUnregisterMsg, deleteUnregisterMsg } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setPlayers, pushPlayers, popPlayers, updatePlayers, deletePlayers, setArea, deleteArea, setBuild, deleteBuild, setBuildWithPos, deleteBuildWithPos, setCountdown, setCountdownEndTimestamp, setCountdownEndBlock, setTokens, pushTokens, popTokens, updateTokens, deleteTokens, setNfts, pushNfts, popNfts, updateNfts, deleteNfts } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setChipMetadata, deleteChipMetadata, setChipAttacher, deleteChipAttacher } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setShop, deleteShop, setBuyShop, setSellShop, setShopBalance } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setForceFieldName, deleteForceFieldMetadata, setForceFieldApprovals, deleteForceFieldApprovals, setFFApprovedPlayers, pushFFApprovedPlayer, popFFApprovedPlayer, updateFFApprovedPlayer, setFFApprovedNFT, pushFFApprovedNFT, popFFApprovedNFT, updateFFApprovedNFT } from "@biomesaw/experience/src/utils/ChipUtils.sol";

import { ForceFieldApprovals } from "@biomesaw/experience/src/codegen/tables/ForceFieldApprovals.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { IAreaNFT } from "./IAreaNFT.sol";

contract Chip is IChip, Ownable {
  constructor(address _biomeWorldAddress) Ownable(msg.sender) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.ForceField,
        name: "NFT Property",
        description: "Holders of the NFT can build/mine in the area"
      })
    );
  }

  function setAreaNFT(address nft) public onlyOwner {
    Metadata.setNftAddress(nft);

    address[] memory nfts = new address[](1);
    nfts[0] = nft;
    setNfts(nfts);
  }

  function mint(address to) public onlyOwner {
    address nftAddress = Metadata.getNftAddress();
    require(nftAddress != address(0), "NFT address not set");
    IAreaNFT(nftAddress).mint(to);
  }

  function getAreaNFT() public view returns (address) {
    return Metadata.getNftAddress();
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IChip).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function onAttached(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {
    setChipAttacher(entityId, getPlayerFromEntity(playerEntityId));
    address nftAddress = getAreaNFT();
    if (nftAddress == address(0)) {
      return;
    }
    address[] memory approvedNfts = new address[](1);
    approvedNfts[0] = nftAddress;
    setFFApprovedNFT(entityId, approvedNfts);
    setForceFieldName(entityId, "Builders NFT Land");
  }

  function onDetached(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {
    deleteForceFieldMetadata(entityId);
    deleteForceFieldApprovals(entityId);
    deleteChipAttacher(entityId);
  }

  function onPowered(bytes32 playerEntityId, bytes32 entityId, uint16 numBattery) public override onlyBiomeWorld {}

  function onChipHit(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {}

  function onTransfer(
    bytes32 srcEntityId,
    bytes32 dstEntityId,
    uint8 transferObjectTypeId,
    uint16 numToTransfer,
    bytes32 toolEntityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {}

  function hasAreaNft(bytes32 playerEntityId) internal returns (bool) {
    address player = getPlayerFromEntity(playerEntityId);
    address areaNFT = getAreaNFT();
    if (areaNFT == address(0)) {
      return false;
    }

    return IAreaNFT(areaNFT).balanceOf(player) > 0;
  }

  function onBuild(
    bytes32 forceFieldEntityId,
    bytes32 playerEntityId,
    uint8 objectTypeId,
    VoxelCoord memory coord,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool) {
    bool allowBuild = hasAreaNft(playerEntityId);
    require(allowBuild, "Player does not have the Builders NFT");
    return allowBuild;
  }

  function onMine(
    bytes32 forceFieldEntityId,
    bytes32 playerEntityId,
    uint8 objectTypeId,
    VoxelCoord memory coord,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool) {
    return hasAreaNft(playerEntityId);
  }
}
