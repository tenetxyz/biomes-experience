import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "tokenizedchest",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
    TotalSupply: {
      schema: {
        token: "address",
        supply: "uint256",
      },
      key: ["token"],
    },
    ChestToken: {
      schema: {
        chestEntityId: "bytes32",
        token: "address",
      },
      key: ["chestEntityId"],
    },
    AllowedSetup: {
      schema: {
        token: "address",
        player: "address",
        allowed: "bool",
      },
      key: ["token", "player"],
    },
  },
});
