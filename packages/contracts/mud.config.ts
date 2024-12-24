import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "privatetext",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
    TextSign: {
      schema: {
        signEntityId: "bytes32",
        content: "string",
      },
      key: ["signEntityId"],
    },
  },
});
