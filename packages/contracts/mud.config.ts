import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "experience",
  tables: {
    ExperienceMetadata: {
      schema: {
        contractAddress: "address",
        shouldDelegate: "bool",
        hookSystemIds: "bytes32[]",
        name: "string",
        description: "string",
      },
      key: []
    },
    DisplayMetadata: {
      schema: {
        status: "string",
        registerMessage: "string",
        unregisterMessage: "string",
      },
      key: [],
      type: "offchainTable"
    },
    Notifications: {
      schema: {
        player: "address",
        message: "string",
      },
      key: [],
      type: "offchainTable"
    },
    Areas: {
      schema: {
        id: "bytes32",
        name: "string",
        lowerSouthwestCorner: "bytes", // VoxelCoord
        size: "bytes", // VoxelCoord
      },
      key: ["id"],
    },
  },
});
