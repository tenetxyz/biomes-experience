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
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PipeAccess } from "@biomesaw/experience/src/codegen/tables/PipeAccess.sol";
import { PipeAccessList } from "@biomesaw/experience/src/codegen/tables/PipeAccessList.sol";
import { Exchange } from "./codegen/tables/Exchange.sol";
import { ExchangeFee } from "./codegen/tables/ExchangeFee.sol";
import { Tokens } from "@biomesaw/experience/src/codegen/tables/Tokens.sol";
import { SmartItemMetadataData } from "@biomesaw/experience/src/codegen/tables/SmartItemMetadata.sol";
import { ExchangeInfo, ExchangeInfoData } from "@biomesaw/experience/src/codegen/tables/ExchangeInfo.sol";
import { ResourceType } from "@biomesaw/experience/src/codegen/common.sol";
import { ExchangeNotif, ExchangeNotifData } from "@biomesaw/experience/src/codegen/tables/ExchangeNotif.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { isStorageContainer } from "@biomesaw/world/src/utils/ObjectTypeUtils.sol";

contract Chip is IChip {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.Chest,
        name: "Liquidity Pool",
        description: "Liquidity pool for swapping between items and tokens"
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
    uint8 callerObjectTypeId = getObjectType(callerEntityId);
    if (isStorageContainer(callerObjectTypeId)) {
      ExchangeInfoData memory buyExchangeInfo = ExchangeInfo.get(chestEntityId, BUY_EXCHANGE_ID);
      ExchangeInfoData memory sellExchangeInfo = ExchangeInfo.get(chestEntityId, SELL_EXCHANGE_ID);
      require(
        buyExchangeInfo.inResourceType == ResourceType.Object &&
          sellExchangeInfo.outResourceType == ResourceType.Object,
        "Chest not setup for pipe access"
      );
      uint8 objectTypeId = decodeObjectExchangeResourceId(buyExchangeInfo.inResourceId);

      uint16 currentNumItemsInChest = getCount(callerEntityId, objectTypeId);

      uint256 newNumItemsInChest = sellExchangeInfo.outMaxAmount + 1;
      if (pipeAccessExists(chestEntityId, callerEntityId)) {
        if (!depositAllowed && !withdrawAllowed) {
          // removing chest from pipe access list, so decrease inMaxAmount
          setExchangeInMaxAmount(
            chestEntityId,
            BUY_EXCHANGE_ID,
            buyExchangeInfo.inMaxAmount - (numMaxInChest(objectTypeId) - currentNumItemsInChest)
          );
          setExchangeOutMaxAmount(
            chestEntityId,
            SELL_EXCHANGE_ID,
            sellExchangeInfo.outMaxAmount - currentNumItemsInChest
          );
          newNumItemsInChest = (sellExchangeInfo.outMaxAmount - currentNumItemsInChest) + 1;
        }
      } else {
        if (depositAllowed || withdrawAllowed) {
          // adding chest to pipe access list, so increase inMaxAmount
          setExchangeInMaxAmount(
            chestEntityId,
            BUY_EXCHANGE_ID,
            buyExchangeInfo.inMaxAmount + (numMaxInChest(objectTypeId) - currentNumItemsInChest)
          );
          setExchangeOutMaxAmount(
            chestEntityId,
            SELL_EXCHANGE_ID,
            sellExchangeInfo.outMaxAmount + currentNumItemsInChest
          );
          newNumItemsInChest = (sellExchangeInfo.outMaxAmount + currentNumItemsInChest) + 1;
        }
      }

      uint256 itemExchangeConstant = Exchange.get(chestEntityId, objectTypeId);
      uint256 newBalance = itemExchangeConstant / newNumItemsInChest;
      uint256 feePercentage = ExchangeFee.get(chestEntityId, objectTypeId);
      setExchangeOutUnitAmount(
        chestEntityId,
        BUY_EXCHANGE_ID,
        getSellPrice(itemExchangeConstant, newBalance, newNumItemsInChest, 1)
      );
      setExchangeInUnitAmount(
        chestEntityId,
        SELL_EXCHANGE_ID,
        getBuyPrice(itemExchangeConstant, newBalance, feePercentage, newNumItemsInChest, 1)
      );
    }

    setPipeAccess(chestEntityId, callerEntityId, depositAllowed, withdrawAllowed);
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

  function setupBuySellShop(
    bytes32 chestEntityId,
    uint8 objectTypeId,
    uint16 initialItemAmount,
    uint256 initialCurrencyAmount,
    address paymentToken,
    uint256 feePercentage
  ) public payable onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);

    uint256 addingBalance = initialCurrencyAmount;

    require(getNumInventoryObjects(chestEntityId) == 1, "Chest must only have one item");
    require(PipeAccessList.lengthAllowedEntityIds(chestEntityId) == 0, "Chest must not have any pipe access");
    require(initialItemAmount > 1, "Initial item amount must be greater than 1");
    require(
      initialItemAmount == getCount(chestEntityId, objectTypeId),
      "Initial item amount must match chest inventory"
    );

    uint256 exchangeConstant = initialItemAmount * initialCurrencyAmount;

    addExchange(
      chestEntityId,
      BUY_EXCHANGE_ID,
      ExchangeInfoData({
        inResourceType: ResourceType.Object,
        inResourceId: encodeObjectExchangeResourceId(objectTypeId),
        inUnitAmount: 1,
        inMaxAmount: numMaxInChest(objectTypeId) - initialItemAmount,
        outResourceType: paymentToken == address(0) ? ResourceType.NativeCurrency : ResourceType.ERC20,
        outResourceId: encodeAddressExchangeResourceId(paymentToken),
        outUnitAmount: getSellPrice(exchangeConstant, addingBalance, initialItemAmount, 1),
        outMaxAmount: addingBalance
      })
    );

    addExchange(
      chestEntityId,
      SELL_EXCHANGE_ID,
      ExchangeInfoData({
        inResourceType: paymentToken == address(0) ? ResourceType.NativeCurrency : ResourceType.ERC20,
        inResourceId: encodeAddressExchangeResourceId(paymentToken),
        inUnitAmount: getBuyPrice(exchangeConstant, addingBalance, feePercentage, initialItemAmount, 1),
        inMaxAmount: type(uint256).max,
        outResourceType: ResourceType.Object,
        outResourceId: encodeObjectExchangeResourceId(objectTypeId),
        outUnitAmount: 1,
        outMaxAmount: initialItemAmount - 1
      })
    );

    Exchange.set(chestEntityId, objectTypeId, exchangeConstant);
    ExchangeFee.set(chestEntityId, objectTypeId, feePercentage);

    if (paymentToken == address(0)) {
      require(msg.value == addingBalance, "Insufficient Ether sent");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transferFrom(admin, address(this), addingBalance), "Failed to transfer tokens");
    }
  }

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) public onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    uint256 newBalance = doWithdraw(admin, chestEntityId, amount);
    setExchangeOutMaxAmount(chestEntityId, BUY_EXCHANGE_ID, newBalance);

    ExchangeInfoData memory buyExchangeInfo = ExchangeInfo.get(chestEntityId, BUY_EXCHANGE_ID);
    ExchangeInfoData memory sellExchangeInfo = ExchangeInfo.get(chestEntityId, SELL_EXCHANGE_ID);
    if (
      buyExchangeInfo.inResourceType == ResourceType.Object && sellExchangeInfo.outResourceType == ResourceType.Object
    ) {
      uint8 exchangeObjectTypeId = decodeObjectExchangeResourceId(buyExchangeInfo.inResourceId);
      uint256 itemExchangeConstant = Exchange.get(chestEntityId, exchangeObjectTypeId);
      uint256 newNumItemsInChest = sellExchangeInfo.outMaxAmount + 1;
      uint256 feePercentage = ExchangeFee.get(chestEntityId, exchangeObjectTypeId);

      setExchangeOutUnitAmount(
        chestEntityId,
        BUY_EXCHANGE_ID,
        getSellPrice(itemExchangeConstant, newBalance, newNumItemsInChest, 1)
      );
      setExchangeInUnitAmount(
        chestEntityId,
        SELL_EXCHANGE_ID,
        getBuyPrice(itemExchangeConstant, newBalance, feePercentage, newNumItemsInChest, 1)
      );
    }
  }

  // Buy from the perspective of the player
  // Sell from the perspective of the chest
  function getBuyPrice(
    uint256 itemExchangeConstant,
    uint256 chestBalance,
    uint256 feePercentage,
    uint256 numItemsInChest,
    uint256 buyAmount
  ) public view returns (uint256) {
    if (buyAmount == 0) {
      return 0;
    }

    if (buyAmount > numItemsInChest) {
      return 0;
    }
    numItemsInChest -= buyAmount;
    if (numItemsInChest == 0) {
      return 0;
    }

    uint256 newBalance = itemExchangeConstant / numItemsInChest;
    if (newBalance < chestBalance) {
      return 0;
    }
    uint256 shopTotalPrice = newBalance - chestBalance;

    uint256 totalFee = (shopTotalPrice * feePercentage) / 100;
    shopTotalPrice += totalFee;

    return shopTotalPrice;
  }

  // Sell from the perspective of the player
  // Buy from the perspective of the chest
  function getSellPrice(
    uint256 itemExchangeConstant,
    uint256 chestBalance,
    uint256 numItemsInChest,
    uint256 sellAmount
  ) public view returns (uint256) {
    if (sellAmount == 0) {
      return 0;
    }

    numItemsInChest += sellAmount;
    uint256 newBalance = itemExchangeConstant / numItemsInChest;

    if (chestBalance < newBalance) {
      return 0;
    }

    uint256 shopTotalPrice = chestBalance - newBalance;

    return shopTotalPrice;
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
    address player = getPlayerFromEntity(transferContext.callerEntityId);
    address admin = ChipAdmin.get(transferContext.targetEntityId);
    ExchangeInfoData memory buyExchangeInfo = ExchangeInfo.get(transferContext.targetEntityId, BUY_EXCHANGE_ID);
    ExchangeInfoData memory sellExchangeInfo = ExchangeInfo.get(transferContext.targetEntityId, SELL_EXCHANGE_ID);

    uint8 exchangeObjectTypeId = transferContext.isDeposit
      ? decodeObjectExchangeResourceId(buyExchangeInfo.inResourceId)
      : decodeObjectExchangeResourceId(sellExchangeInfo.outResourceId);
    {
      require(admin != address(0), "Chest does not exist");
      require(player != address(0), "Player does not exist");
      if (player == admin && exchangeObjectTypeId == NullObjectTypeId) {
        return true;
      }
    }

    if (exchangeObjectTypeId != transferContext.transferData.objectTypeId) {
      return false;
    }
    for (uint i = 0; i < transferContext.transferData.toolEntityIds.length; i++) {
      require(
        getNumUsesLeft(transferContext.transferData.toolEntityIds[i]) == getDurability(exchangeObjectTypeId),
        "Tool must have full durability"
      );
    }

    uint256 itemExchangeConstant = Exchange.get(
      transferContext.targetEntityId,
      transferContext.transferData.objectTypeId
    );
    uint256 newNumItemsInChest = sellExchangeInfo.outMaxAmount + 1;
    if (transferContext.isDeposit) {
      newNumItemsInChest += transferContext.transferData.numToTransfer;
    } else {
      newNumItemsInChest -= transferContext.transferData.numToTransfer;
    }
    require(newNumItemsInChest > 0, "Chest must have at least one item");
    uint256 newBalance = itemExchangeConstant / newNumItemsInChest;
    setExchangeOutMaxAmount(transferContext.targetEntityId, BUY_EXCHANGE_ID, newBalance);

    uint256 shopTotalPrice;
    uint256 feePercentage = ExchangeFee.get(transferContext.targetEntityId, transferContext.transferData.objectTypeId);
    if (transferContext.isDeposit) {
      // Check if there is enough balance in the chest
      require(buyExchangeInfo.outMaxAmount >= newBalance, "Insufficient balance in chest");
      shopTotalPrice = buyExchangeInfo.outMaxAmount - newBalance;

      uint256 newInMaxAmount = buyExchangeInfo.inMaxAmount - transferContext.transferData.numToTransfer;
      setExchangeInMaxAmount(transferContext.targetEntityId, BUY_EXCHANGE_ID, newInMaxAmount);

      uint256 newOutMaxAmount = sellExchangeInfo.outMaxAmount + transferContext.transferData.numToTransfer;
      setExchangeOutMaxAmount(transferContext.targetEntityId, SELL_EXCHANGE_ID, newOutMaxAmount);

      if (buyExchangeInfo.outResourceType == ResourceType.NativeCurrency) {
        (bool sent, ) = player.call{ value: shopTotalPrice }("");
        require(sent, "Failed to send Ether");
      } else {
        IERC20 token = IERC20(decodeAddressExchangeResourceId(buyExchangeInfo.outResourceId));
        require(token.transfer(player, shopTotalPrice), "Failed to transfer tokens");
      }
    } else {
      require(newBalance >= buyExchangeInfo.outMaxAmount, "Insufficient balance in chest");
      shopTotalPrice = newBalance - buyExchangeInfo.outMaxAmount;
      uint256 totalFee = (shopTotalPrice * feePercentage) / 100;

      uint256 newInMaxAmount = buyExchangeInfo.inMaxAmount + transferContext.transferData.numToTransfer;
      setExchangeInMaxAmount(transferContext.targetEntityId, BUY_EXCHANGE_ID, newInMaxAmount);

      uint256 newOutMaxAmount = sellExchangeInfo.outMaxAmount - transferContext.transferData.numToTransfer;
      setExchangeOutMaxAmount(transferContext.targetEntityId, SELL_EXCHANGE_ID, newOutMaxAmount);

      if (sellExchangeInfo.inResourceType == ResourceType.NativeCurrency) {
        require(msg.value == shopTotalPrice + totalFee, "Insufficient Ether sent");
        (bool sent, ) = admin.call{ value: totalFee }("");
        require(sent, "Failed to send Ether");
      } else {
        IERC20 token = IERC20(decodeAddressExchangeResourceId(sellExchangeInfo.inResourceId));
        require(token.transferFrom(player, address(this), shopTotalPrice), "Failed to transfer tokens");
        require(token.transferFrom(player, admin, totalFee), "Failed to transfer tokens");
      }
    }

    setExchangeOutUnitAmount(
      transferContext.targetEntityId,
      BUY_EXCHANGE_ID,
      getSellPrice(itemExchangeConstant, newBalance, newNumItemsInChest, 1)
    );
    setExchangeInUnitAmount(
      transferContext.targetEntityId,
      SELL_EXCHANGE_ID,
      getBuyPrice(itemExchangeConstant, newBalance, feePercentage, newNumItemsInChest, 1)
    );

    emitExchangeNotif(
      transferContext.targetEntityId,
      ExchangeNotifData({
        player: player,
        inResourceType: transferContext.isDeposit ? buyExchangeInfo.inResourceType : sellExchangeInfo.inResourceType,
        inResourceId: transferContext.isDeposit ? buyExchangeInfo.inResourceId : sellExchangeInfo.inResourceId,
        inAmount: transferContext.isDeposit ? transferContext.transferData.numToTransfer : shopTotalPrice,
        outResourceType: transferContext.isDeposit ? buyExchangeInfo.outResourceType : sellExchangeInfo.outResourceType,
        outResourceId: transferContext.isDeposit ? buyExchangeInfo.outResourceId : sellExchangeInfo.outResourceId,
        outAmount: transferContext.isDeposit ? shopTotalPrice : transferContext.transferData.numToTransfer
      })
    );

    return true;
  }

  function onPipeTransfer(
    ChipOnPipeTransferData memory transferContext
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    return
      transferContext.isDeposit
        ? PipeAccess.getDepositAllowed(transferContext.targetEntityId, transferContext.callerEntityId)
        : PipeAccess.getWithdrawAllowed(transferContext.targetEntityId, transferContext.callerEntityId);
  }

  receive() external payable {
    // This function is executed when a contract receives plain Ether (without data)
  }
}
