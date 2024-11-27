import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "privateimage",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
    ImageDisplay: {
      schema: {
        signEntityId: "bytes32",
        url: "string",
      },
      key: ["signEntityId"],
    },
  },
});
