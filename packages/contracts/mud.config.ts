import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "ownedchest",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
  },
});
