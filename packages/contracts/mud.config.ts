import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "buildfordrops",
  tables: {
    GameMetadata: {
      schema: {
        allowedDrops: "address[]",
      },
      key: [],
    },
    Builder: {
      schema: {
        x: "int16",
        y: "int16",
        z: "int16",
        builder: "address",
      },
      key: ["x", "y", "z"]
    },
    Metadata: {
      schema: {
        experienceAddress: "address",
      },
      key: [],
    },
  },
});
