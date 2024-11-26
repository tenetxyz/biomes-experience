import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "subpasschest",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
    ShopMetadata: {
      schema: {
        shopNFT: "address",
        shopNFTNextTokenId: "uint256",
      },
      key: [],
    },
    AllowedSetup: {
      schema: {
        player: "address",
        allowed: "bool",
      },
      key: ["player"],
    },
    MintedNFT: {
      schema: {
        player: "address",
        minted: "bool",
      },
      key: ["player"],
    },
    BoughtObject: {
      schema: {
        player: "address",
        objectTypeId: "uint8",
        bought: "bool",
      },
      key: ["player", "objectTypeId"],
    },
    SoldObject: {
      schema: {
        player: "address",
        objectTypeId: "uint8",
        numSold: "uint256",
      },
      key: ["player", "objectTypeId"],
    }
  },
});
