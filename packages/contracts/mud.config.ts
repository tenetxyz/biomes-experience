import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "batterytdc",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
        paymentToken: "address",
      },
      key: [],
    },
    SecurityLevel: {
      schema: {
        chestEntityId: "bytes32",
        minLevel: "uint256",
      },
      key: ["chestEntityId"],
    },
  },
});
