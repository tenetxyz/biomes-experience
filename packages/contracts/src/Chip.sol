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

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ForceFieldApprovals } from "@biomesaw/experience/src/codegen/tables/ForceFieldApprovals.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";

contract Chip is IChip {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.ForceField,
        name: "Private Property",
        description: "You can build and mine in this force field area and add approved players and NFTs"
      })
    );
  }

  function setDisplayName(bytes32 entityId, string memory name) public {
    require(ChipAttachment.getAttacher(entityId) == msg.sender, "Only the attacher can set the force field name");
    setForceFieldName(entityId, name);
  }

  function addApprovedPlayer(bytes32 entityId, address player) public {
    require(ChipAttachment.getAttacher(entityId) == msg.sender, "Only the attacher can add approved players");
    address[] memory approvedPlayers = ForceFieldApprovals.getPlayers(entityId);
    address[] memory newApprovedPlayers = new address[](approvedPlayers.length + 1);
    for (uint256 i = 0; i < approvedPlayers.length; i++) {
      require(approvedPlayers[i] != player, "Player is already approved");
      newApprovedPlayers[i] = approvedPlayers[i];
    }
    newApprovedPlayers[approvedPlayers.length] = player;
    setFFApprovedPlayers(entityId, newApprovedPlayers);
  }

  function removeApprovedPlayer(bytes32 entityId, address player) public {
    require(ChipAttachment.getAttacher(entityId) == msg.sender, "Only the attacher can remove approved players");
    require(isApprovedPlayer(entityId, player), "Player is not approved");
    address[] memory approvedPlayers = ForceFieldApprovals.getPlayers(entityId);
    address[] memory newApprovedPlayers = new address[](approvedPlayers.length - 1);
    uint256 j = 0;
    for (uint256 i = 0; i < approvedPlayers.length; i++) {
      if (approvedPlayers[i] == player) {
        continue;
      }
      newApprovedPlayers[j] = approvedPlayers[i];
      j++;
    }
    setFFApprovedPlayers(entityId, newApprovedPlayers);
  }

  function addApprovedNFT(bytes32 entityId, address nft) public {
    require(ChipAttachment.getAttacher(entityId) == msg.sender, "Only the attacher can add approved NFTs");
    address[] memory approvedNfts = ForceFieldApprovals.getNfts(entityId);
    address[] memory newApprovedNfts = new address[](approvedNfts.length + 1);
    for (uint256 i = 0; i < approvedNfts.length; i++) {
      require(approvedNfts[i] != nft, "NFT is already approved");
      newApprovedNfts[i] = approvedNfts[i];
    }
    newApprovedNfts[approvedNfts.length] = nft;
    setFFApprovedNFT(entityId, newApprovedNfts);
  }

  function removeApprovedNFT(bytes32 entityId, address nft) public {
    require(ChipAttachment.getAttacher(entityId) == msg.sender, "Only the attacher can remove approved NFTs");
    address[] memory approvedNfts = ForceFieldApprovals.getNfts(entityId);
    bool hasApprovedNft = false;
    for (uint256 i = 0; i < approvedNfts.length; i++) {
      if (approvedNfts[i] == nft) {
        hasApprovedNft = true;
        break;
      }
    }
    require(hasApprovedNft, "NFT is not approved");
    address[] memory newApprovedNfts = new address[](approvedNfts.length - 1);
    uint256 j = 0;
    for (uint256 i = 0; i < approvedNfts.length; i++) {
      if (approvedNfts[i] == nft) {
        continue;
      }
      newApprovedNfts[j] = approvedNfts[i];
      j++;
    }
    setFFApprovedNFT(entityId, newApprovedNfts);
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
    address[] memory approvedPlayers = new address[](1);
    approvedPlayers[0] = getPlayerFromEntity(playerEntityId);
    setFFApprovedPlayers(entityId, approvedPlayers);
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

  function isApprovedPlayer(bytes32 forceFieldEntityId, address player) internal returns (bool) {
    address[] memory approvedPlayers = ForceFieldApprovals.getPlayers(forceFieldEntityId);
    for (uint256 i = 0; i < approvedPlayers.length; i++) {
      if (approvedPlayers[i] == player) {
        return true;
      }
    }

    return false;
  }

  function hasApprovedNft(bytes32 forceFieldEntityId, address player) internal returns (bool) {
    address[] memory approvedNfts = ForceFieldApprovals.getNfts(forceFieldEntityId);
    for (uint256 i = 0; i < approvedNfts.length; i++) {
      if (IERC721(approvedNfts[i]).balanceOf(player) > 0) {
        return true;
      }
    }

    return false;
  }

  function isApproved(bytes32 forceFieldEntityId, address player) internal returns (bool) {
    return isApprovedPlayer(forceFieldEntityId, player) || hasApprovedNft(forceFieldEntityId, player);
  }

  function onBuild(
    bytes32 forceFieldEntityId,
    bytes32 playerEntityId,
    uint8 objectTypeId,
    VoxelCoord memory coord,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool) {
    address player = getPlayerFromEntity(playerEntityId);
    require(isApproved(forceFieldEntityId, player), "Player is not approved to build in this area");
    return true;
  }

  function onMine(
    bytes32 forceFieldEntityId,
    bytes32 playerEntityId,
    uint8 objectTypeId,
    VoxelCoord memory coord,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address player = getPlayerFromEntity(playerEntityId);
    return isApproved(forceFieldEntityId, player);
  }
}
