import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "bazaarchest",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
    Exchange: {
      schema: {
        objectTypeId: "uint8",
        kConstant: "uint256",
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
