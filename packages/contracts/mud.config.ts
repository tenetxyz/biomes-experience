import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "bountyhunter",
  tables: {
    PlayerMetadata: {
      schema: {
        player: "address",
        balance: "uint256",
        lastWithdrawalTime: "uint256",
        lastHitter: "address",
        isRegistered: "bool"
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
