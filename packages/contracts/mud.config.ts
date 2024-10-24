import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "buysellchest",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
    Fees: {
      schema: {
        token: "address",
        fee: "uint256",
      },
      key: ["token"],
    },
  },
});
