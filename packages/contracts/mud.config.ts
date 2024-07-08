import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "deathmatch",
  tables: {
    GameMetadata: {
      schema: {
        isGameStarted: "bool",
        gameStarter: "address",
        players: "address[]",
      },
      key: [],
    },
    PlayerMetadata: {
      schema: {
        player: "address",
        numKills: "uint256",
        isAlive: "bool",
        isDisqualified: "bool",
        isRegistered: "bool",
      },
      key: ["player"],
    },
    Metadata: {
      schema: {
        experienceAddress: "address",
      },
      key: [],
    },
  },
});
