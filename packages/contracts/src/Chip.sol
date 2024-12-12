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

import { CHIP_NAMESPACE } from "./Constants.sol";
import { IChip } from "./IChip.sol";

import { SmartItemMetadataData } from "@biomesaw/experience/src/codegen/tables/SmartItemMetadata.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Chip is IChip {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.ForceField,
        name: "Settlement",
        description: "You control this area - decide which players or pass-holders can build and mine inside."
      })
    );
    setNamespaceId(WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE));
  }

  modifier onlyChipNamespace() {
    require(getCallerNamespace(msg.sender) == CHIP_NAMESPACE, "Caller is not a system in the Chip namespace");
    _; // Continue execution
  }

  function changeAdmin(bytes32 entityId, address newAdmin) public onlyChipNamespace {
    setChipAdmin(entityId, newAdmin);
  }

  function setDisplayData(bytes32 entityId, string memory name, string memory description) public onlyChipNamespace {
    setSmartItemMetadata(entityId, SmartItemMetadataData({ name: name, description: description }));
  }

  function setApprovedPlayers(bytes32 entityId, address[] memory players) public onlyChipNamespace {
    setGateApprovedPlayers(entityId, players);
  }

  function setApprovedNFTs(bytes32 entityId, address[] memory nfts) public onlyChipNamespace {
    setGateApprovedNFT(entityId, nfts);
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IForceFieldChip).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function onAttached(
    bytes32 callerEntityId,
    bytes32 targetEntityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address player = getPlayerFromEntity(callerEntityId);
    setChipAttacher(targetEntityId, player);
    setChipAdmin(targetEntityId, player);
    return true;
  }

  function onDetached(
    bytes32 callerEntityId,
    bytes32 targetEntityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address admin = ChipAdmin.get(targetEntityId);
    address player = getPlayerFromEntity(callerEntityId);
    deleteGateApprovals(targetEntityId);
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

  function onBuild(
    bytes32 targetEntityId,
    bytes32 callerEntityId,
    uint8 objectTypeId,
    VoxelCoord memory coord,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address player = getPlayerFromEntity(callerEntityId);
    return isApprovedForGate(targetEntityId, player);
  }

  function onMine(
    bytes32 targetEntityId,
    bytes32 callerEntityId,
    uint8 objectTypeId,
    VoxelCoord memory coord,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address player = getPlayerFromEntity(callerEntityId);
    return isApprovedForGate(targetEntityId, player);
  }
}
