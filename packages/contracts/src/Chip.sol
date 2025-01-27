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

import { CHIP_NAMESPACE, BUY_EXCHANGE_ID, SELL_EXCHANGE_ID } from "./Constants.sol";
import { IChip } from "./IChip.sol";

import { AccessControl } from "@latticexyz/world/src/AccessControl.sol";
import { SmartItemMetadataData } from "@biomesaw/experience/src/codegen/tables/SmartItemMetadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ExchangeInfo, ExchangeInfoData } from "@biomesaw/experience/src/codegen/tables/ExchangeInfo.sol";
import { ResourceType } from "@biomesaw/experience/src/codegen/common.sol";
import { ExchangeNotif, ExchangeNotifData } from "@biomesaw/experience/src/codegen/tables/ExchangeNotif.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";

contract Chip is IChip {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.Chest,
        name: "Shop",
        description: "You control this chest. Buy & sell items for token prices you set"
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

  function adminTransfer(address paymentToken, uint256 amount, address receiver) public {
    AccessControl.requireOwner(WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE), msg.sender);
    if (paymentToken == address(this)) {
      (bool sent, ) = receiver.call{ value: amount }("");
      require(sent, "Failed to send Ether");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transfer(receiver, amount), "Failed to transfer tokens");
    }
  }

  function doWithdraw(address player, bytes32 chestEntityId, uint256 amount) internal returns (uint256) {
    require(amount > 0, "Amount must be greater than 0");
    uint256 currentBalance = ExchangeInfo.getOutMaxAmount(chestEntityId, BUY_EXCHANGE_ID);
    require(currentBalance >= amount, "Insufficient balance");
    uint256 newBalance = currentBalance - amount;

    if (ExchangeInfo.getOutResourceType(chestEntityId, BUY_EXCHANGE_ID) == ResourceType.NativeCurrency) {
      (bool sent, ) = player.call{ value: amount }("");
      require(sent, "Failed to send Ether");
    } else {
      address paymentToken = decodeAddressExchangeResourceId(
        ExchangeInfo.getOutResourceId(chestEntityId, BUY_EXCHANGE_ID)
      );
      IERC20 token = IERC20(paymentToken);
      require(token.transfer(player, amount), "Failed to transfer tokens");
    }

    return newBalance;
  }

  function setupBuyShop(
    bytes32 chestEntityId,
    uint8 buyObjectTypeId,
    uint256 buyPrice,
    uint256 buyAmount,
    address paymentToken
  ) public payable onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    uint256 addingBalance = buyPrice * buyAmount;

    addExchange(
      chestEntityId,
      BUY_EXCHANGE_ID,
      ExchangeInfoData({
        inResourceType: ResourceType.Object,
        inResourceId: encodeObjectExchangeResourceId(buyObjectTypeId),
        inUnitAmount: 1,
        inMaxAmount: buyAmount,
        outResourceType: paymentToken == address(0) ? ResourceType.NativeCurrency : ResourceType.ERC20,
        outResourceId: encodeAddressExchangeResourceId(paymentToken),
        outUnitAmount: buyPrice,
        outMaxAmount: addingBalance
      })
    );

    if (paymentToken == address(0)) {
      require(msg.value == addingBalance, "Insufficient Ether sent");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transferFrom(admin, address(this), addingBalance), "Failed to transfer tokens");
    }
  }

  function setupSellShop(
    bytes32 chestEntityId,
    uint8 sellObjectTypeId,
    uint256 sellPrice,
    address paymentToken
  ) public onlyChipNamespace {
    addExchange(
      chestEntityId,
      SELL_EXCHANGE_ID,
      ExchangeInfoData({
        inResourceType: paymentToken == address(0) ? ResourceType.NativeCurrency : ResourceType.ERC20,
        inResourceId: encodeAddressExchangeResourceId(paymentToken),
        inUnitAmount: sellPrice,
        inMaxAmount: type(uint256).max,
        outResourceType: ResourceType.Object,
        outResourceId: encodeObjectExchangeResourceId(sellObjectTypeId),
        outUnitAmount: 1,
        outMaxAmount: getCount(chestEntityId, sellObjectTypeId)
      })
    );
  }

  function setupBuySellShop(
    bytes32 chestEntityId,
    uint8 objectTypeId,
    uint256 buyPrice,
    uint256 buyAmount,
    uint256 sellPrice,
    address paymentToken
  ) public payable onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    uint256 addingBalance = buyPrice * buyAmount;

    addExchange(
      chestEntityId,
      BUY_EXCHANGE_ID,
      ExchangeInfoData({
        inResourceType: ResourceType.Object,
        inResourceId: encodeObjectExchangeResourceId(objectTypeId),
        inUnitAmount: 1,
        inMaxAmount: buyAmount,
        outResourceType: paymentToken == address(0) ? ResourceType.NativeCurrency : ResourceType.ERC20,
        outResourceId: encodeAddressExchangeResourceId(paymentToken),
        outUnitAmount: buyPrice,
        outMaxAmount: addingBalance
      })
    );

    addExchange(
      chestEntityId,
      SELL_EXCHANGE_ID,
      ExchangeInfoData({
        inResourceType: paymentToken == address(0) ? ResourceType.NativeCurrency : ResourceType.ERC20,
        inResourceId: encodeAddressExchangeResourceId(paymentToken),
        inUnitAmount: sellPrice,
        inMaxAmount: type(uint256).max,
        outResourceType: ResourceType.Object,
        outResourceId: encodeObjectExchangeResourceId(objectTypeId),
        outUnitAmount: 1,
        outMaxAmount: getCount(chestEntityId, objectTypeId)
      })
    );

    if (paymentToken == address(0)) {
      require(msg.value == addingBalance, "Insufficient Ether sent");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transferFrom(admin, address(this), addingBalance), "Failed to transfer tokens");
    }
  }

  function changeBuyPrice(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 newPrice) public onlyChipNamespace {
    ExchangeInfoData memory buyExchange = ExchangeInfo.get(chestEntityId, BUY_EXCHANGE_ID);
    require(buyExchange.inResourceId == encodeObjectExchangeResourceId(buyObjectTypeId), "Chest is not set up");

    setExchangeOutUnitAmount(chestEntityId, BUY_EXCHANGE_ID, newPrice);
    uint256 newBuyAmount = newPrice > 0 ? buyExchange.outMaxAmount / newPrice : numMaxInChest(buyObjectTypeId);
    setExchangeInMaxAmount(chestEntityId, BUY_EXCHANGE_ID, newBuyAmount);
  }

  function changeSellPrice(bytes32 chestEntityId, uint8 sellObjectTypeId, uint256 newPrice) public onlyChipNamespace {
    require(
      ExchangeInfo.getOutResourceId(chestEntityId, SELL_EXCHANGE_ID) ==
        encodeObjectExchangeResourceId(sellObjectTypeId),
      "Chest is not set up"
    );

    setExchangeInUnitAmount(chestEntityId, SELL_EXCHANGE_ID, newPrice);
  }

  function buyMore(bytes32 chestEntityId, uint8 buyObjectTypeId, uint256 buyAmount) public payable onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    ExchangeInfoData memory buyExchange = ExchangeInfo.get(chestEntityId, BUY_EXCHANGE_ID);
    require(buyExchange.inResourceId == encodeObjectExchangeResourceId(buyObjectTypeId), "Chest is not set up");
    uint256 refillAmount = buyAmount * buyExchange.outUnitAmount;
    uint256 newBalance = buyExchange.outMaxAmount + refillAmount;
    setExchangeOutMaxAmount(chestEntityId, BUY_EXCHANGE_ID, newBalance);
    uint256 newInMaxAmount = buyExchange.inMaxAmount + buyAmount;
    setExchangeInMaxAmount(chestEntityId, BUY_EXCHANGE_ID, newInMaxAmount);

    if (buyExchange.outResourceType == ResourceType.NativeCurrency) {
      require(msg.value == refillAmount, "Insufficient Ether sent");
    } else {
      IERC20 token = IERC20(decodeAddressExchangeResourceId(buyExchange.outResourceId));
      require(token.transferFrom(admin, address(this), refillAmount), "Failed to transfer tokens");
    }
  }

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) public onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    uint256 newBalance = doWithdraw(admin, chestEntityId, amount);
    setExchangeOutMaxAmount(chestEntityId, BUY_EXCHANGE_ID, newBalance);
    uint256 buyPrice = ExchangeInfo.getOutUnitAmount(chestEntityId, BUY_EXCHANGE_ID);
    uint256 newBuyAmount = buyPrice > 0
      ? newBalance / buyPrice
      : numMaxInChest(decodeObjectExchangeResourceId(ExchangeInfo.getInResourceId(chestEntityId, BUY_EXCHANGE_ID)));
    setExchangeInMaxAmount(chestEntityId, BUY_EXCHANGE_ID, newBuyAmount);
  }

  function destroyShop(bytes32 chestEntityId) public onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    uint256 currentBalance = ExchangeInfo.getOutMaxAmount(chestEntityId, BUY_EXCHANGE_ID);
    if (currentBalance > 0) {
      doWithdraw(admin, chestEntityId, currentBalance);
    }
    deleteExchanges(chestEntityId);
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

    uint256 currentBalance = ExchangeInfo.getOutMaxAmount(targetEntityId, BUY_EXCHANGE_ID);
    if (currentBalance > 0) {
      doWithdraw(admin, targetEntityId, currentBalance);
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
    ExchangeInfoData memory exchangeInfo = ExchangeInfo.get(
      transferContext.targetEntityId,
      transferContext.isDeposit ? BUY_EXCHANGE_ID : SELL_EXCHANGE_ID
    );
    uint8 exchangeObjectTypeId = transferContext.isDeposit
      ? decodeObjectExchangeResourceId(exchangeInfo.inResourceId)
      : decodeObjectExchangeResourceId(exchangeInfo.outResourceId);
    for (uint i = 0; i < transferContext.transferData.toolEntityIds.length; i++) {
      require(
        getNumUsesLeft(transferContext.transferData.toolEntityIds[i]) == getDurability(exchangeObjectTypeId),
        "Tool must have full durability"
      );
    }

    if (player == admin) {
      if (transferContext.isDeposit) {
        exchangeInfo = ExchangeInfo.get(transferContext.targetEntityId, SELL_EXCHANGE_ID);
        exchangeObjectTypeId = decodeObjectExchangeResourceId(exchangeInfo.outResourceId);
        if (exchangeObjectTypeId != transferContext.transferData.objectTypeId) {
          return false;
        }
        uint256 newOutMaxAmount = exchangeInfo.outMaxAmount + transferContext.transferData.numToTransfer;
        setExchangeOutMaxAmount(transferContext.targetEntityId, SELL_EXCHANGE_ID, newOutMaxAmount);
        return true;
      } else {
        if (exchangeInfo.outResourceType == ResourceType.Object) {
          uint256 newOutMaxAmount = exchangeInfo.outMaxAmount - transferContext.transferData.numToTransfer;
          setExchangeOutMaxAmount(transferContext.targetEntityId, SELL_EXCHANGE_ID, newOutMaxAmount);
        }
        return true;
      }
    }

    if (exchangeObjectTypeId != transferContext.transferData.objectTypeId) {
      return false;
    }

    uint256 shopPrice = transferContext.isDeposit ? exchangeInfo.outUnitAmount : exchangeInfo.inUnitAmount;
    if (shopPrice == 0) {
      // TODO: Update max amounts
      return true;
    }

    uint256 shopTotalPrice = transferContext.transferData.numToTransfer * shopPrice;

    if (transferContext.isDeposit) {
      // Check if there is enough balance in the chest
      uint256 balance = exchangeInfo.outMaxAmount;
      require(balance >= shopTotalPrice, "Insufficient balance in chest");
      uint256 newBalance = balance - shopTotalPrice;
      setExchangeOutMaxAmount(transferContext.targetEntityId, BUY_EXCHANGE_ID, newBalance);
      uint256 newInMaxAmount = exchangeInfo.inMaxAmount - transferContext.transferData.numToTransfer;
      setExchangeInMaxAmount(transferContext.targetEntityId, BUY_EXCHANGE_ID, newInMaxAmount);

      if (exchangeInfo.outResourceType == ResourceType.NativeCurrency) {
        (bool sent, ) = player.call{ value: shopTotalPrice }("");
        require(sent, "Failed to send Ether");
      } else {
        IERC20 token = IERC20(decodeAddressExchangeResourceId(exchangeInfo.outResourceId));
        require(token.transfer(player, shopTotalPrice), "Failed to transfer tokens");
      }
    } else {
      if (exchangeInfo.inResourceType == ResourceType.NativeCurrency) {
        require(msg.value == shopTotalPrice, "Insufficient Ether sent");

        (bool sent, ) = admin.call{ value: shopTotalPrice }("");
        require(sent, "Failed to send Ether");
      } else {
        IERC20 token = IERC20(decodeAddressExchangeResourceId(exchangeInfo.inResourceId));
        require(token.transferFrom(player, admin, shopTotalPrice), "Failed to transfer tokens");
      }

      uint256 newOutMaxAmount = exchangeInfo.outMaxAmount - transferContext.transferData.numToTransfer;
      setExchangeOutMaxAmount(transferContext.targetEntityId, SELL_EXCHANGE_ID, newOutMaxAmount);
    }

    emitExchangeNotif(
      transferContext.targetEntityId,
      ExchangeNotifData({
        player: player,
        inResourceType: exchangeInfo.inResourceType,
        inResourceId: exchangeInfo.inResourceId,
        inAmount: transferContext.isDeposit ? transferContext.transferData.numToTransfer : shopTotalPrice,
        outResourceType: exchangeInfo.outResourceType,
        outResourceId: exchangeInfo.outResourceId,
        outAmount: transferContext.isDeposit ? shopTotalPrice : transferContext.transferData.numToTransfer
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
