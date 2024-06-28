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
    Players: {
      schema: {
        players: "address[]",
      },
      key: [],
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
    Builds: {
      schema: {
        id: "bytes32",
        name: "string",
        objectTypeIds: "uint8[]",
        relativePositions: "bytes", // VoxelCoord[]
      },
      key: ["id"],
    },
    BuildsWithPos: {
      schema: {
        id: "bytes32",
        name: "string",
        objectTypeIds: "uint8[]",
        relativePositions: "bytes", // VoxelCoord[]
        baseWorldCoord: "bytes", // VoxelCoord
      },
      key: ["id"],
    },
    Countdown: {
      schema: {
        countdownEndTimestamp: "uint256",
        countdownEndBlock: "uint256",
      },
      key: [],
    },
    Tokens: {
      schema: {
        tokens: "address[]",
      },
      key: [],
    },
  },
});
