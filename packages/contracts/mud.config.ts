import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "locationguard",
  tables: {
    GameMetadata: {
      schema: {
        guardPositionX: "int16",
        guardPositionY: "int16",
        guardPositionZ: "int16",
        unguardPositionsX: "int16[]",
        unguardPositionsY: "int16[]",
        unguardPositionsZ: "int16[]",
        allowedPlayers: "address[]",
      },
      key: [],
    },
    Metadata: {
      schema: {
        experienceAddress: "address",
      },
      key: [],
    },
  },
});
