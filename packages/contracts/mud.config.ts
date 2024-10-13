import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "bazaar",
  tables: {
    Metadata: {
      schema: {
        objectTypeId: "uint8",
        chipAddress: "address",
        exchangeToken: "address",
      },
      key: ["objectTypeId"],
    },
    Exchange: {
      schema: {
        objectTypeId: "uint8",
        price: "uint256",
        lastPurchaseTime: "uint256",
        sold: "uint256",
      },
      key: ["objectTypeId"],
    },
    AllowedSetup: {
      schema: {
        player: "address",
        allowed: "bool",
      },
      key: ["player"],
    },
  },
});
