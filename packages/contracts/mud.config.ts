import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "itemnftchest",
  userTypes: {
    ResourceId: { filePath: "@latticexyz/store/src/ResourceId.sol", type: "bytes32" },
  },
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
    ShopNFT: {
      schema: {
        chestEntityId: "bytes32",
        nftNamespaceId: "ResourceId",
      },
      key: ["chestEntityId"],
    },
    OwnedNFTs: {
      schema: {
        owner: "address",
        nfts: "address[]",
      },
      key: ["owner"],
    },
    NFTMetadata: {
      schema: {
        nftAddress: "address",
        owner: "address",
        objectTypeId: "uint8",
        objectAmount: "uint256",
        nftNextTokenId: "uint256",
      },
      key: ["nftAddress"],
    },
    MintedNFT: {
      schema: {
        player: "address",
        nftAddress: "address",
        minted: "bool",
      },
      key: ["player", "nftAddress"],
    },
  },
});
