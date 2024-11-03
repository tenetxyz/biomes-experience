import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "parkourchest",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
    ShopMetadata: {
      schema: {
        chestEntityId: "bytes32",
        paymentToken: "address",
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
  },
});
