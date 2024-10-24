import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "uniswapchest",
  tables: {
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
    Exchange: {
      schema: {
        chestEntityId: "bytes32",
        objectTypeId: "uint8",
        kConstant: "uint256",
      },
      key: ["chestEntityId", "objectTypeId"],
    },
  },
});
