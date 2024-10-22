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
import { PlayerObjectID, AirObjectID, DirtObjectID, ChestObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";
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

import { MAX_CHEST_INVENTORY_SLOTS } from "@biomesaw/world/src/Constants.sol";
import { IShopToken } from "./IShopToken.sol";
import { TotalSupply } from "./codegen/tables/TotalSupply.sol";
import { ObjectToken } from "./codegen/tables/ObjectToken.sol";
import { Tokens } from "@biomesaw/experience/src/codegen/tables/Tokens.sol";
import { ItemShop, ItemShopData } from "@biomesaw/experience/src/codegen/tables/ItemShop.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";

contract Chip is IChestChip, Ownable {
  constructor(address _biomeWorldAddress) Ownable(msg.sender) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.Chest,
        name: "Buy & Sell Blocks via Dynamic Pricing",
        description: "Players receive tokens for placing blocks in your chest, let players take blocks from your chest by sending tokens. Token price is determined by a formula."
      })
    );
  }

  function updateObjectToToken(uint8 objectTypeId, address tokenAddress) public onlyOwner {
    address[] memory tokens = Tokens.get(address(this));
    address previousTokenAddress = ObjectToken.getTokenAddress(objectTypeId);

    bool addToken = true;
    bool removePreviousToken = false;
    for (uint i = 0; i < tokens.length; i++) {
      if (tokens[i] == tokenAddress) {
        addToken = false;
        break;
      }
      if (tokens[i] == previousTokenAddress) {
        removePreviousToken = true;
      }
    }

    if (addToken) {
      if (removePreviousToken) {
        address[] memory newTokens = new address[](tokens.length);
        uint j = 0;
        for (uint i = 0; i < tokens.length; i++) {
          if (tokens[i] != previousTokenAddress) {
            newTokens[j] = tokens[i];
            j++;
          } else {
            newTokens[j] = tokenAddress;
            j++;
          }
        }
        setTokens(tokens);
      } else {
        pushTokens(tokenAddress);
      }
    } else {
      if (removePreviousToken) {
        address[] memory newTokens = new address[](tokens.length - 1);
        uint j = 0;
        for (uint i = 0; i < tokens.length; i++) {
          if (tokens[i] != previousTokenAddress) {
            newTokens[j] = tokens[i];
            j++;
          }
        }
        setTokens(tokens);
      }
    }
    ObjectToken.setTokenAddress(objectTypeId, tokenAddress);
  }

  function setupShop(bytes32 chestEntityId, uint8 objectTypeId) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can set up the shop");
    require(ItemShop.getObjectTypeId(chestEntityId) == NullObjectTypeId, "Chest already has a shop");
    address token = ObjectToken.getTokenAddress(objectTypeId);
    require(token != address(0), "Token not set up");

    setShop(
      chestEntityId,
      ItemShopData({
        shopType: ShopType.BuySell,
        objectTypeId: objectTypeId,
        buyPrice: 0,
        sellPrice: 0,
        balance: 0,
        paymentToken: token
      })
    );
  }

  function destroyShop(bytes32 chestEntityId, uint8 objectTypeId) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can destroy the chest");
    require(ItemShop.getObjectTypeId(chestEntityId) == NullObjectTypeId, "Chest is not set up");

    uint16 currentSupplyInChest = getCount(chestEntityId, objectTypeId);
    uint256 currentTotalSupply = TotalSupply.get(objectTypeId);
    uint256 newTotalSupply = currentTotalSupply > currentSupplyInChest ? currentTotalSupply - currentSupplyInChest : 0;
    TotalSupply.set(objectTypeId, newTotalSupply);

    deleteShop(chestEntityId);
  }

  function getObjectSupply(uint8 objectTypeId) public view returns (uint256) {
    return TotalSupply.get(objectTypeId);
  }

  function getObjectToken(uint8 objectTypeId) public view returns (address) {
    return ObjectToken.getTokenAddress(objectTypeId);
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
    setChipAttacher(entityId, getPlayerFromEntity(playerEntityId));
    return true;
  }

  function onDetached(
    bytes32 playerEntityId,
    bytes32 entityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address owner = ChipAttachment.getAttacher(entityId);
    address player = getPlayerFromEntity(playerEntityId);
    deleteChipAttacher(entityId);

    uint8 shopObjectTypeId = ItemShop.getObjectTypeId(entityId);

    if (shopObjectTypeId != NullObjectTypeId) {
      uint16 currentSupplyInChest = getCount(entityId, shopObjectTypeId);
      uint256 currentTotalSupply = TotalSupply.get(shopObjectTypeId);
      uint256 newTotalSupply = currentTotalSupply > currentSupplyInChest
        ? currentTotalSupply - currentSupplyInChest
        : 0;
      TotalSupply.set(shopObjectTypeId, newTotalSupply);

      // Clear existing shop data
      deleteShop(entityId);
    }
    return owner == player;
  }

  function onPowered(bytes32 playerEntityId, bytes32 entityId, uint16 numBattery) public override onlyBiomeWorld {}

  function onChipHit(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {}

  function blocksToTokens(
    uint256 supply,
    uint8 transferObjectTypeId,
    uint16 transferAmount,
    bool isDeposit
  ) internal view returns (uint256) {
    // Constant that adjusts the base rate of tokens per block
    uint256 k = 10 * 10 ** 18;

    // Constant that controls how the reward rate decreases as the chest fills up
    // uint256 alpha = 0.001;

    uint256 maxItemsInChest = getStackable(transferObjectTypeId) * MAX_CHEST_INVENTORY_SLOTS;

    // Cumulatively sum the supply as it increases
    uint256 tokens = 0;
    for (uint16 i = 0; i < transferAmount; i++) {
      // Map supply to the range of 0 -- 10x10^10
      uint256 scaledSupply = (supply * 10 ** 10) / maxItemsInChest;

      tokens += (k * 1) / (1 + (scaledSupply / 1000));

      if (isDeposit) {
        supply++;
      } else {
        if (supply > 0) {
          supply--;
        }
      }
    }

    return tokens;
  }

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

    address owner = ChipAttachment.getAttacher(chestEntityId);
    require(owner != address(0), "Chest does not exist");
    uint256 curentTotalSupply = TotalSupply.get(transferObjectTypeId);

    address tokenAddress = ObjectToken.getTokenAddress(transferObjectTypeId);
    require(tokenAddress != address(0), "Token not set up");
    address player = getPlayerFromEntity(isDeposit ? srcEntityId : dstEntityId);
    require(player != address(0), "Player does not exist");

    uint256 blockTokens = blocksToTokens(curentTotalSupply, transferObjectTypeId, numToTransfer, isDeposit);

    uint256 newTotalSupply = isDeposit
      ? curentTotalSupply + numToTransfer
      : curentTotalSupply > numToTransfer
        ? curentTotalSupply - numToTransfer
        : 0;
    TotalSupply.set(transferObjectTypeId, newTotalSupply);

    if (isDeposit) {
      IShopToken(tokenAddress).mint(player, blockTokens);
    } else {
      // Note: ERC20 will check if the player has enough tokens
      IShopToken(tokenAddress).burn(player, blockTokens);
    }

    return true;
  }
}
