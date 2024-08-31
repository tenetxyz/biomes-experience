import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "settlersunion",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
    BankMetadata: {
      schema: {
        bankToken: "address",
        objectSupply: "uint256",
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
  },
});
