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
import { hasBeforeAndAfterSystemHook, getObjectTypeAtCoord, getTerrainBlock, getEntityAtCoord, getPosition, getObjectType, getMiningDifficulty, getStackable, getDamage, getDurability, isTool, isBlock, getEntityFromPlayer, getPlayerFromEntity, getEquipped, getHealth, getStamina, getIsLoggedOff, getLastHitTime, getInventoryTool, getInventoryObjects, getNumInventoryObjects, getCount, getNumSlotsUsed, getNumUsesLeft } from "@biomesaw/experience/src/utils/EntityUtils.sol";
import { Area, insideArea, insideAreaIgnoreY, getEntitiesInArea, getArea } from "@biomesaw/experience/src/utils/AreaUtils.sol";
import { Build, BuildWithPos, buildExistsInWorld, buildWithPosExistsInWorld, getBuild, getBuildWithPos } from "@biomesaw/experience/src/utils/BuildUtils.sol";
import { weiToString, getEmptyBlockOnGround } from "@biomesaw/experience/src/utils/GameUtils.sol";
import { setExperienceMetadata, setJoinFee, deleteExperienceMetadata, setNotification, deleteNotifications, setStatus, deleteStatus, setRegisterMsg, deleteRegisterMsg, setUnregisterMsg, deleteUnregisterMsg } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setPlayers, pushPlayers, popPlayers, updatePlayers, deletePlayers, setArea, deleteArea, setBuild, deleteBuild, setBuildWithPos, deleteBuildWithPos, setCountdown, setCountdownEndTimestamp, setCountdownEndBlock, setTokens, pushTokens, popTokens, updateTokens, deleteTokens, setNfts, pushNfts, popNfts, updateNfts, deleteNfts } from "@biomesaw/experience/src/utils/ExperienceUtils.sol";
import { setChipMetadata, deleteChipMetadata, setChipAttacher, deleteChipAttacher } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setShop, deleteShop, setBuyShop, setSellShop, setShopBalance, setBuyPrice, setSellPrice, setShopObjectTypeId } from "@biomesaw/experience/src/utils/ChipUtils.sol";
import { setChestMetadata, setChestName, setChestDescription, deleteChestMetadata, setForceFieldMetadata, setForceFieldName, setForceFieldDescription, deleteForceFieldMetadata, setForceFieldApprovals, deleteForceFieldApprovals, setFFApprovedPlayers, pushFFApprovedPlayer, popFFApprovedPlayer, updateFFApprovedPlayer, setFFApprovedNFT, pushFFApprovedNFT, popFFApprovedNFT, updateFFApprovedNFT } from "@biomesaw/experience/src/utils/ChipUtils.sol";

import { IShopToken } from "./IShopToken.sol";
import { ChestToken } from "./codegen/tables/ChestToken.sol";
import { TotalSupply } from "./codegen/tables/TotalSupply.sol";
import { AllowedSetup } from "./codegen/tables/AllowedSetup.sol";
import { Tokens } from "@biomesaw/experience/src/codegen/tables/Tokens.sol";
import { ChestMetadataData } from "@biomesaw/experience/src/codegen/tables/ChestMetadata.sol";
import { ItemShop, ItemShopData } from "@biomesaw/experience/src/codegen/tables/ItemShop.sol";
import { ShopType } from "@biomesaw/experience/src/codegen/common.sol";
import { ChipAttachment } from "@biomesaw/experience/src/codegen/tables/ChipAttachment.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";

contract Chip is IChip, Ownable {
  constructor(address _biomeWorldAddress) Ownable(msg.sender) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);

    initChip();
  }

  function initChip() internal {
    setChipMetadata(
      ChipMetadataData({
        chipType: ChipType.Chest,
        name: "Buy & Sell Blocks via Stablecoin",
        description: "Token supply controlled by the chip. Players receive a single token for each block placed in the chest, and can take a block for each token deposited."
      })
    );
  }

  function setDisplayData(bytes32 chestEntityId, string memory name, string memory description) public {
    require(
      ChipAttachment.getAttacher(chestEntityId) == msg.sender,
      "Only the attacher can set the chest display data"
    );
    setChestMetadata(chestEntityId, ChestMetadataData({ name: name, description: description }));
  }

  function addAllowedSetup(address attacher) public {
    AllowedSetup.set(msg.sender, attacher, true);
  }

  function setupShop(bytes32 chestEntityId, uint8 objectTypeId, address tokenAddress) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can set up the shop");
    require(ItemShop.getObjectTypeId(chestEntityId) == NullObjectTypeId, "Chest already has a shop");
    require(tokenAddress != address(0), "Token address cannot be 0");
    require(AllowedSetup.get(tokenAddress, msg.sender), "Not allowed to set up shop for this token");

    ChestToken.setToken(chestEntityId, tokenAddress);

    setShop(
      chestEntityId,
      ItemShopData({
        shopType: ShopType.BuySell,
        objectTypeId: objectTypeId,
        buyPrice: 0,
        sellPrice: 0,
        balance: 0,
        paymentToken: tokenAddress
      })
    );
  }

  function destroyShop(bytes32 chestEntityId, uint8 objectTypeId) public {
    require(ChipAttachment.getAttacher(chestEntityId) == msg.sender, "Only the attacher can destroy the chest");
    require(ItemShop.getObjectTypeId(chestEntityId) == objectTypeId, "Chest is not set up");
    address tokenAddress = ChestToken.getToken(chestEntityId);
    require(tokenAddress != address(0), "Token address cannot be 0");

    uint16 currentSupplyInChest = getCount(chestEntityId, objectTypeId);
    if (currentSupplyInChest > 0) {
      uint256 currentTotalSupply = TotalSupply.get(tokenAddress);
      uint256 newTotalSupply = currentTotalSupply > currentSupplyInChest
        ? currentTotalSupply - currentSupplyInChest
        : 0;
      TotalSupply.set(tokenAddress, newTotalSupply);
    }

    ChestToken.deleteRecord(chestEntityId);

    deleteChestMetadata(chestEntityId);

    deleteShop(chestEntityId);
  }

  function getChestToken(bytes32 chestEntityId) public view returns (address) {
    return ChestToken.getToken(chestEntityId);
  }

  function getObjectSupply(address token) public view returns (uint256) {
    return TotalSupply.get(token);
  }

  function getChestTokenSupply(bytes32 chestEntityId) public view returns (uint256) {
    return IShopToken(getChestToken(chestEntityId)).totalSupply();
  }

  function getObjectAndTokenSupply(bytes32 chestEntityId) external view returns (uint256, uint256) {
    address chestToken = getChestToken(chestEntityId);
    return (getObjectSupply(chestToken), IShopToken(chestToken).totalSupply());
  }

  modifier onlyBiomeWorld() {
    require(msg.sender == WorldContextConsumerLib._world(), "Caller is not the Biomes World contract");
    _; // Continue execution
  }

  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IChip).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  function onAttached(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {
    require(getNumInventoryObjects(entityId) == 0, "Chest must be empty");
    setChipAttacher(entityId, getPlayerFromEntity(playerEntityId));
  }

  function onDetached(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {
    deleteChestMetadata(entityId);

    uint8 shopObjectTypeId = ItemShop.getObjectTypeId(entityId);

    if (shopObjectTypeId != NullObjectTypeId) {
      uint16 currentSupplyInChest = getCount(entityId, shopObjectTypeId);
      if (currentSupplyInChest > 0) {
        address tokenAddress = ChestToken.getToken(entityId);
        uint256 currentTotalSupply = TotalSupply.get(tokenAddress);
        uint256 newTotalSupply = currentTotalSupply > currentSupplyInChest
          ? currentTotalSupply - currentSupplyInChest
          : 0;
        TotalSupply.set(tokenAddress, newTotalSupply);
      }

      ChestToken.deleteRecord(entityId);

      // Clear existing shop data
      deleteShop(entityId);
    }

    deleteChipAttacher(entityId);
  }

  function onPowered(bytes32 playerEntityId, bytes32 entityId, uint16 numBattery) public override onlyBiomeWorld {}

  function onChipHit(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {}

  function blocksToTokens(
    uint256 totalTokenSupply,
    uint256 supply,
    uint8 transferObjectTypeId,
    uint16 transferAmount,
    bool isDeposit
  ) internal view returns (uint256) {
    // Cumulatively sum the supply as it increases
    uint256 tokens = 0;
    for (uint16 i = 0; i < transferAmount; i++) {
      uint256 tokenIncrease = 0;
      if (supply == 0) {
        tokenIncrease = 1 * 10 ** 18;
      } else {
        tokenIncrease = totalTokenSupply / supply;
      }
      tokens += tokenIncrease;

      if (isDeposit) {
        supply++;
        totalTokenSupply += tokenIncrease;
      } else {
        if (supply > 0) {
          supply--;
        }
        if (totalTokenSupply > tokenIncrease) {
          totalTokenSupply -= tokenIncrease;
        } else {
          totalTokenSupply = 0;
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
    bytes32 toolEntityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool) {
    bool isDeposit = getObjectType(srcEntityId) == PlayerObjectID;
    bytes32 chestEntityId = isDeposit ? dstEntityId : srcEntityId;
    {
      ItemShopData memory chestShopData = ItemShop.get(chestEntityId);
      if (chestShopData.objectTypeId != transferObjectTypeId) {
        return false;
      }
      if (toolEntityId != bytes32(0)) {
        require(
          getNumUsesLeft(toolEntityId) == getDurability(chestShopData.objectTypeId),
          "Tool must have full durability"
        );
      }
    }

    address tokenAddress = ChestToken.getToken(chestEntityId);
    require(tokenAddress != address(0), "Token not set up");
    uint256 tokenSupply = IShopToken(tokenAddress).totalSupply();
    address player = getPlayerFromEntity(isDeposit ? srcEntityId : dstEntityId);
    require(player != address(0), "Player does not exist");

    uint256 curentTotalSupply = TotalSupply.get(tokenAddress);

    uint256 blockTokens = blocksToTokens(
      tokenSupply,
      curentTotalSupply,
      transferObjectTypeId,
      numToTransfer,
      isDeposit
    );

    uint256 newTotalSupply = isDeposit
      ? curentTotalSupply + numToTransfer
      : curentTotalSupply > numToTransfer
        ? curentTotalSupply - numToTransfer
        : 0;
    TotalSupply.set(tokenAddress, newTotalSupply);

    if (isDeposit) {
      IShopToken(tokenAddress).mint(player, blockTokens);
    } else {
      // Note: ERC20 will check if the player has enough tokens
      IShopToken(tokenAddress).burn(player, blockTokens);
    }

    return true;
  }

  function onBuild(
    bytes32 forceFieldEntityId,
    bytes32 playerEntityId,
    uint8 objectTypeId,
    VoxelCoord memory coord,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {}

  function onMine(
    bytes32 forceFieldEntityId,
    bytes32 playerEntityId,
    uint8 objectTypeId,
    VoxelCoord memory coord,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {}
}
