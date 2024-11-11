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

import { AccessControlLib } from "@latticexyz/world-modules/src/utils/AccessControlLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Exchange } from "./codegen/tables/Exchange.sol";
import { ExchangeFee } from "./codegen/tables/ExchangeFee.sol";
import { Tokens } from "@biomesaw/experience/src/codegen/tables/Tokens.sol";
import { SmartItemMetadataData } from "@biomesaw/experience/src/codegen/tables/SmartItemMetadata.sol";
import { ItemShop, ItemShopData } from "@biomesaw/experience/src/codegen/tables/ItemShop.sol";
import { ShopType, ShopTxType } from "@biomesaw/experience/src/codegen/common.sol";
import { ItemShopNotifData } from "@biomesaw/experience/src/codegen/tables/ItemShopNotif.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { SilverBarObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { setShop, deleteShop, setBuyShop, setSellShop, setShopBalance, setBuyPrice, setSellPrice, setShopObjectTypeId, emitShopNotif } from "@biomesaw/experience/src/utils/ChipUtils.sol";

contract Chip is IChip {
  constructor(address _biomeWorldAddress) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.Chest,
        name: "Uniswap Chest",
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

  function refillBuyShopBalance(
    bytes32 chestEntityId,
    uint8 buyObjectTypeId,
    uint256 refillAmount
  ) public payable onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    require(ItemShop.getObjectTypeId(chestEntityId) == buyObjectTypeId, "Chest is not set up");

    address paymentToken = ItemShop.getPaymentToken(chestEntityId);

    uint256 newBalance = ItemShop.getBalance(chestEntityId) + refillAmount;
    setShopBalance(chestEntityId, newBalance);

    if (paymentToken == address(0)) {
      require(msg.value == refillAmount, "Insufficient Ether sent");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transferFrom(admin, address(this), refillAmount), "Failed to transfer tokens");
    }
  }

  function withdrawBuyShopBalance(bytes32 chestEntityId, uint256 amount) public onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    uint256 newBalance = doWithdraw(admin, chestEntityId, amount);
    setShopBalance(chestEntityId, newBalance);
  }

  function setupBuySellShop(
    bytes32 chestEntityId,
    uint8 objectTypeId,
    uint256 initialItemAmount,
    uint256 initialCurrencyAmount,
    address paymentToken,
    uint256 feePercentage
  ) public payable onlyChipNamespace {
    address admin = ChipAdmin.get(chestEntityId);
    require(ItemShop.getObjectTypeId(chestEntityId) == NullObjectTypeId, "Chest already has a shop");

    uint256 addingBalance = initialCurrencyAmount;
    uint256 newBalance = ItemShop.getBalance(chestEntityId) + addingBalance;
    require(getNumInventoryObjects(chestEntityId) == 1, "Chest must only have one item");
    require(initialItemAmount > 0, "Initial item amount must be greater than 0");
    require(
      initialItemAmount == getCount(chestEntityId, objectTypeId),
      "Initial item amount must match chest inventory"
    );

    setShop(
      chestEntityId,
      ItemShopData({
        shopType: ShopType.BuySell,
        objectTypeId: objectTypeId,
        buyPrice: 0,
        sellPrice: 0,
        balance: newBalance,
        paymentToken: paymentToken
      })
    );

    uint256 exchangeConstant = initialItemAmount * initialCurrencyAmount;
    Exchange.set(chestEntityId, objectTypeId, exchangeConstant);
    ExchangeFee.set(chestEntityId, objectTypeId, feePercentage);

    if (paymentToken == address(0)) {
      require(msg.value == addingBalance, "Insufficient Ether sent");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transferFrom(admin, address(this), addingBalance), "Failed to transfer tokens");
    }
  }

  function doWithdraw(address player, bytes32 chestEntityId, uint256 amount) internal returns (uint256) {
    require(amount > 0, "Amount must be greater than 0");
    uint256 currentBalance = ItemShop.getBalance(chestEntityId);
    require(currentBalance >= amount, "Insufficient balance");
    uint256 newBalance = currentBalance - amount;

    address paymentToken = ItemShop.getPaymentToken(chestEntityId);
    if (paymentToken == address(0)) {
      (bool sent, ) = player.call{ value: amount }("");
      require(sent, "Failed to send Ether");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transfer(player, amount), "Failed to transfer tokens");
    }

    return newBalance;
  }

  function adminWithdraw(address paymentToken, uint256 amount) public {
    address admin = msg.sender;
    AccessControlLib.requireOwner(WorldResourceIdLib.encodeNamespace(CHIP_NAMESPACE), admin);
    if (paymentToken == address(this)) {
      (bool sent, ) = admin.call{ value: amount }("");
      require(sent, "Failed to send Ether");
    } else {
      IERC20 token = IERC20(paymentToken);
      require(token.transfer(admin, amount), "Failed to transfer tokens");
    }
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

    deleteSmartItemMetadata(targetEntityId);
    uint256 currentBalance = ItemShop.getBalance(targetEntityId);
    if (currentBalance > 0) {
      doWithdraw(admin, targetEntityId, currentBalance);
    }

    if (ItemShop.getObjectTypeId(targetEntityId) != NullObjectTypeId) {
      // Clear existing shop data
      deleteShop(targetEntityId);
    }

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
    address player = getPlayerFromEntity(transferData.callerEntityId);
    ItemShopData memory chestShopData = ItemShop.get(transferData.targetEntityId);
    address admin = ChipAdmin.get(transferData.targetEntityId);
    {
      require(admin != address(0), "Chest does not exist");
      require(player != address(0), "Player does not exist");
      if (player == admin && chestShopData.objectTypeId == NullObjectTypeId) {
        return true;
      }
    }

    if (chestShopData.objectTypeId != transferObjectTypeId) {
      return false;
    }
    for (uint i = 0; i < toolEntityIds.length; i++) {
      require(
        getNumUsesLeft(toolEntityIds[i]) != getDurability(chestShopData.objectTypeId),
        "Tool must have full durability"
      );
    }

    uint256 newBalance;
    {
      uint256 itemExchangeConstant = Exchange.get(chestEntityId, transferObjectTypeId);
      uint16 newNumItemsInChest = getCount(chestEntityId, transferObjectTypeId);
      require(newNumItemsInChest > 0, "Chest must have at least one item");
      newBalance = itemExchangeConstant / newNumItemsInChest;
    }
    setShopBalance(chestEntityId, newBalance);

    uint256 shopTotalPrice;
    if (isDeposit) {
      // Check if there is enough balance in the chest
      require(chestShopData.balance >= newBalance, "Insufficient balance in chest");
      shopTotalPrice = chestShopData.balance - newBalance;

      if (chestShopData.paymentToken == address(0)) {
        (bool sent, ) = player.call{ value: shopTotalPrice }("");
        require(sent, "Failed to send Ether");
      } else {
        IERC20 token = IERC20(chestShopData.paymentToken);
        require(token.transfer(player, shopTotalPrice), "Failed to transfer tokens");
      }
    } else {
      require(newBalance >= chestShopData.balance, "Insufficient balance in chest");
      shopTotalPrice = newBalance - chestShopData.balance;
      uint256 totalFee = (shopTotalPrice * ExchangeFee.get(chestEntityId, transferObjectTypeId)) / 100;

      if (chestShopData.paymentToken == address(0)) {
        require(msg.value == shopTotalPrice + totalFee, "Insufficient Ether sent");
        (bool sent, ) = admin.call{ value: totalFee }("");
        require(sent, "Failed to send Ether");
      } else {
        IERC20 token = IERC20(chestShopData.paymentToken);
        require(token.transferFrom(player, address(this), shopTotalPrice), "Failed to transfer tokens");
        require(token.transferFrom(player, admin, totalFee), "Failed to transfer tokens");
      }
    }

    emitShopNotif(
      chestEntityId,
      ItemShopNotifData({
        player: player,
        shopTxType: isDeposit ? ShopTxType.Sell : ShopTxType.Buy,
        objectTypeId: chestShopData.objectTypeId,
        price: shopTotalPrice,
        amount: numToTransfer,
        paymentToken: chestShopData.paymentToken
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
