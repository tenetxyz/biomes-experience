import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "dynamicchest",
  tables: {
    TotalSupply: {
      schema: {
        objectTypeId: "uint8",
        supply: "uint256",
      },
      key: ["objectTypeId"],
    },
    ObjectToken: {
      schema: {
        objectTypeId: "uint8",
        tokenAddress: "address",
      },
      key: ["objectTypeId"],
    },
    Metadata: {
      schema: {
        chipAddress: "address",
      },
      key: [],
    },
  },
});
