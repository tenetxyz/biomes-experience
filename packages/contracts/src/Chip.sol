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
import { ChipOnTransferData, ChipOnPipeTransferData, TransferData, PipeTransferData } from "@biomesaw/world/src/Types.sol";
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
import { PlayerObjectID, AirObjectID, DirtObjectID, ChestObjectID, ChipBatteryObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
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

import { IERC20Mintable } from "@latticexyz/world-modules/src/modules/erc20-puppet/IERC20Mintable.sol";
import { SmartItemMetadataData } from "@biomesaw/experience/src/codegen/tables/SmartItemMetadata.sol";
import { PipeAccess } from "@biomesaw/experience/src/codegen/tables/PipeAccess.sol";
import { Metadata } from "./codegen/tables/Metadata.sol";
import { SecurityLevel } from "./codegen/tables/SecurityLevel.sol";
import { ChipData } from "@biomesaw/world/src/codegen/tables/Chip.sol";
import { ExchangeInfo, ExchangeInfoData } from "@biomesaw/experience/src/codegen/tables/ExchangeInfo.sol";
import { BUY_EXCHANGE_ID, SELL_EXCHANGE_ID } from "./Constants.sol";

contract Chip is IChip {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.Chest,
        name: "Battery TDC",
        description: "A chest that can store battery items"
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

  function setDisplayData(
    bytes32 chestEntityId,
    string memory name,
    string memory description
  ) public onlyChipNamespace {
    setSmartItemMetadata(chestEntityId, SmartItemMetadataData({ name: name, description: description }));
  }

  function configurePipeAccess(
    bytes32 chestEntityId,
    bytes32 callerEntityId,
    bool depositAllowed,
    bool withdrawAllowed
  ) public onlyChipNamespace {
    setPipeAccess(chestEntityId, callerEntityId, depositAllowed, withdrawAllowed);
  }

  function chargeForceField(bytes32 chestEntityId, PipeTransferData memory pipeTransferData) public onlyChipNamespace {
    ChipData memory targetChipData = getLatestChipData(chestEntityId);
    bytes32 targetForceFieldEntityId = getForceField(chestEntityId);
    require(targetForceFieldEntityId != bytes32(0), "Force field not found");
    ChipData memory targetForceFieldChipData = getLatestChipData(targetForceFieldEntityId);
    targetChipData.batteryLevel += targetForceFieldChipData.batteryLevel;

    uint256 targetSecurityLevel = SecurityLevel.get(chestEntityId);
    require(
      targetChipData.batteryLevel < targetSecurityLevel,
      "You can only charge the force field when it is not full"
    );
    require(pipeTransferData.targetEntityId == targetForceFieldEntityId, "Invalid force field entity id");
    require(pipeTransferData.transferData.objectTypeId == ChipBatteryObjectID, "Invalid object type id");
    // TODO: ensure right amount of batteries
    IWorld(WorldContextConsumerLib._world()).pipeTransfer(chestEntityId, true, pipeTransferData);
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

    uint8 objectTypeId = ChipBatteryObjectID;
    uint256 buyPrice = 1e18;
    uint256 sellPrice = 1e18;

    address paymentToken = Metadata.getPaymentToken();
    require(paymentToken != address(0), "Payment token not set");

    addExchange(
      targetEntityId,
      BUY_EXCHANGE_ID,
      ExchangeInfoData({
        inResourceType: ResourceType.Object,
        inResourceId: encodeObjectExchangeResourceId(objectTypeId),
        inUnitAmount: 1,
        inMaxAmount: numMaxInChest(objectTypeId),
        outResourceType: paymentToken == address(0) ? ResourceType.NativeCurrency : ResourceType.ERC20,
        outResourceId: encodeAddressExchangeResourceId(paymentToken),
        outUnitAmount: buyPrice,
        outMaxAmount: type(uint256).max
      })
    );

    addExchange(
      targetEntityId,
      SELL_EXCHANGE_ID,
      ExchangeInfoData({
        inResourceType: paymentToken == address(0) ? ResourceType.NativeCurrency : ResourceType.ERC20,
        inResourceId: encodeAddressExchangeResourceId(paymentToken),
        inUnitAmount: sellPrice,
        inMaxAmount: type(uint256).max,
        outResourceType: ResourceType.Object,
        outResourceId: encodeObjectExchangeResourceId(objectTypeId),
        outUnitAmount: 1,
        outMaxAmount: numMaxInChest(objectTypeId)
      })
    );

    setChipAttacher(targetEntityId, player);
    setChipAdmin(targetEntityId, player);
    SecurityLevel.set(targetEntityId, 5 days);
    return true;
  }

  function onDetached(
    bytes32 callerEntityId,
    bytes32 targetEntityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address admin = ChipAdmin.get(targetEntityId);
    address player = getPlayerFromEntity(callerEntityId);
    SecurityLevel.deleteRecord(targetEntityId);
    deletePipeAccessList(targetEntityId);
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
    require(transferContext.transferData.objectTypeId == ChipBatteryObjectID, "Only battery items can be transferred");

    ChipData memory targetChipData = getLatestChipData(transferContext.targetEntityId);
    bytes32 targetForceFieldEntityId = getForceField(transferContext.targetEntityId);
    require(targetForceFieldEntityId != bytes32(0), "Force field not found");
    ChipData memory targetForceFieldChipData = getLatestChipData(targetForceFieldEntityId);
    targetChipData.batteryLevel += targetForceFieldChipData.batteryLevel;
    uint256 targetSecurityLevel = SecurityLevel.get(transferContext.targetEntityId);
    require(
      targetChipData.batteryLevel >= targetSecurityLevel,
      "You can only use the chest when the force field is charged"
    );

    address player = getPlayerFromEntity(transferContext.callerEntityId);
    require(player != address(0), "Player not found");

    address paymentToken = Metadata.getPaymentToken();
    require(paymentToken != address(0), "Payment token not set");

    if (transferContext.isDeposit) {
      // mint tokens
      IERC20Mintable(paymentToken).mint(player, transferContext.transferData.numToTransfer * 1e18);
    } else {
      // burn tokens
      IERC20Mintable(paymentToken).burn(player, transferContext.transferData.numToTransfer * 1e18);
    }

    return true;
  }

  function onPipeTransfer(
    ChipOnPipeTransferData memory transferContext
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    if (transferContext.isDeposit) {
      return PipeAccess.getDepositAllowed(transferContext.targetEntityId, transferContext.callerEntityId);
    } else {
      return PipeAccess.getWithdrawAllowed(transferContext.callerEntityId, transferContext.targetEntityId);
    }
  }
}
