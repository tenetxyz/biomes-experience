import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "buychest",
  tables: {
    Metadata: {
      schema: {
        totalFees: "uint256",
        chipAddress: "address",
      },
      key: [],
    },
  },
});
