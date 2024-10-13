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

import { IERC20Mintable } from "@latticexyz/world-modules/src/modules/erc20-puppet/IERC20Mintable.sol";
import { BankMetadata } from "./codegen/tables/BankMetadata.sol";
import { AllowedSetup } from "./codegen/tables/AllowedSetup.sol";
import { Tokens } from "@biomesaw/experience/src/codegen/tables/Tokens.sol";
import { ChestMetadataData } from "@biomesaw/experience/src/codegen/tables/ChestMetadata.sol";
import { ItemShop, ItemShopData } from "@biomesaw/experience/src/codegen/tables/ItemShop.sol";
import { ShopType } from "@biomesaw/experience/src/codegen/common.sol";
import { ItemShopNotifData } from "@biomesaw/experience/src/codegen/tables/ItemShopNotif.sol";
import { NullObjectTypeId } from "@biomesaw/world/src/ObjectTypeIds.sol";
import { SilverBarObjectID } from "@biomesaw/world/src/ObjectTypeIds.sol";

contract Chip is IChestChip, Ownable {
  constructor(address _biomeWorldAddress) Ownable(msg.sender) {
    StoreSwitch.setStoreAddress(_biomeWorldAddress);
  }

  function setDisplayData(bytes32 chestEntityId, string memory name, string memory description) public {
    require(
      ChipAttachment.getAttacher(chestEntityId) == msg.sender,
      "Only the attacher can set the chest display data"
    );
    setChestMetadata(chestEntityId, ChestMetadataData({ name: name, description: description }));
  }

  function renounceNamespaceOwnership(ResourceId namespaceId) public onlyOwner {
    IWorld(WorldContextConsumerLib._world()).transferOwnership(namespaceId, _msgSender());
  }

  function addAllowedSetup(address attacher) public onlyOwner {
    AllowedSetup.set(attacher, true);
  }

  function setBankToken(address tokenAddress) public onlyOwner {
    address[] memory tokens = new address[](1);
    tokens[0] = tokenAddress;
    setTokens(tokens);
    BankMetadata.setBankToken(tokenAddress);
    BankMetadata.setObjectSupply(0);
  }

  function getBuyUnitPrice(bytes32 chestEntityId) public view returns (uint256) {
    return
      blocksToTokens(
        IERC20Mintable(BankMetadata.getBankToken()).totalSupply(),
        BankMetadata.getObjectSupply(),
        ItemShop.getObjectTypeId(chestEntityId),
        1,
        false
      );
  }

  function getSellUnitPrice(bytes32 chestEntityId) public view returns (uint256) {
    return
      blocksToTokens(
        IERC20Mintable(BankMetadata.getBankToken()).totalSupply(),
        BankMetadata.getObjectSupply(),
        ItemShop.getObjectTypeId(chestEntityId),
        1,
        true
      );
  }

  function getBuySellUnitPrices(bytes32 chestEntityId) public view returns (uint256, uint256) {
    return (getBuyUnitPrice(chestEntityId), getSellUnitPrice(chestEntityId));
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
    address player = getPlayerFromEntity(playerEntityId);
    setChipAttacher(entityId, player);

    address tokenAddress = BankMetadata.getBankToken();
    require(tokenAddress != address(0), "Token address cannot be 0");

    setShop(
      entityId,
      ItemShopData({
        shopType: ShopType.BuySell,
        objectTypeId: SilverBarObjectID,
        buyPrice: 0,
        sellPrice: 0,
        balance: 0,
        paymentToken: tokenAddress
      })
    );
    return AllowedSetup.get(player);
  }

  function onDetached(
    bytes32 playerEntityId,
    bytes32 entityId,
    bytes memory extraData
  ) public payable override onlyBiomeWorld returns (bool isAllowed) {
    address owner = ChipAttachment.getAttacher(entityId);
    address player = getPlayerFromEntity(playerEntityId);

    uint8 shopObjectTypeId = ItemShop.getObjectTypeId(entityId);

    if (shopObjectTypeId != NullObjectTypeId) {
      uint16 currentSupplyInChest = getCount(entityId, shopObjectTypeId);
      if (currentSupplyInChest > 0) {
        uint256 currentObjectSupply = BankMetadata.getObjectSupply();
        uint256 newObjectSupply = currentObjectSupply > currentSupplyInChest
          ? currentObjectSupply - currentSupplyInChest
          : 0;
        BankMetadata.setObjectSupply(newObjectSupply);
      }

      // Clear existing shop data
      deleteShop(entityId);
    }

    deleteChestMetadata(entityId);
    deleteChipAttacher(entityId);
    return owner == player;
  }

  function onPowered(bytes32 playerEntityId, bytes32 entityId, uint16 numBattery) public override onlyBiomeWorld {}

  function onChipHit(bytes32 playerEntityId, bytes32 entityId) public override onlyBiomeWorld {}

  function blocksToTokens(
    uint256 tokenSupply,
    uint256 objectSupply,
    uint8 objectTypeId,
    uint16 transferAmount,
    bool isDeposit
  ) internal view returns (uint256) {
    // Cumulatively sum the objectSupply as it increases/decreases
    uint256 tokens = 0;
    for (uint16 i = 0; i < transferAmount; i++) {
      uint256 tokenIncrease = 0;
      if (objectSupply == 0) {
        tokenIncrease = 100 * 10 ** 18;
      } else {
        tokenIncrease = tokenSupply / objectSupply;
      }
      tokens += tokenIncrease;

      if (isDeposit) {
        objectSupply++;
        tokenSupply += tokenIncrease;
      } else {
        if (objectSupply > 0) {
          objectSupply--;
        }
        if (tokenSupply > tokenIncrease) {
          tokenSupply -= tokenIncrease;
        } else {
          tokenSupply = 0;
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
    {
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
    }

    address tokenAddress = BankMetadata.getBankToken();
    require(tokenAddress != address(0), "Token not set up");
    uint256 tokenSupply = IERC20Mintable(tokenAddress).totalSupply();
    address player = getPlayerFromEntity(isDeposit ? srcEntityId : dstEntityId);
    require(player != address(0), "Player does not exist");

    uint256 objectSupply = BankMetadata.getObjectSupply();
    uint256 blockTokens = blocksToTokens(tokenSupply, objectSupply, transferObjectTypeId, numToTransfer, isDeposit);

    {
      uint256 newObjectSupply = isDeposit
        ? objectSupply + numToTransfer
        : objectSupply > numToTransfer
          ? objectSupply - numToTransfer
          : 0;
      BankMetadata.setObjectSupply(newObjectSupply);
    }

    if (isDeposit) {
      IERC20Mintable(tokenAddress).mint(player, blockTokens);
    } else {
      // Note: ERC20 will check if the player has enough tokens
      IERC20Mintable(tokenAddress).burn(player, blockTokens);
    }

    emitShopNotif(
      chestEntityId,
      ItemShopNotifData({
        player: player,
        shopTxType: isDeposit ? ShopTxType.Sell : ShopTxType.Buy,
        objectTypeId: transferObjectTypeId,
        price: blockTokens,
        amount: numToTransfer,
        paymentToken: tokenAddress
      })
    );

    return true;
  }
}
