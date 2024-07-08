import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "testexperience",
  tables: {
    Metadata: {
      schema: {
        experienceAddress: "address",
      },
      key: [],
    },
  },
});
