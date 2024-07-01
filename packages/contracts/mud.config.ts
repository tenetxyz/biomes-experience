import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "experience",
  tables: {
    ExperienceMetadata: {
      schema: {
        contractAddress: "address",
        shouldDelegate: "bool",
        joinFee: "uint256",
        hookSystemIds: "bytes32[]",
        name: "string",
        description: "string",
      },
      key: []
    },
    DisplayStatus: {
      schema: {
        status: "string",
      },
      key: [],
      type: "offchainTable"
    },
    DisplayRegisterMsg: {
      schema: {
        registerMessage: "string",
      },
      key: [],
      type: "offchainTable"
    },
    DisplayUnregisterMsg: {
      schema: {
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
        lowerSouthwestCornerX: "int16",
        lowerSouthwestCornerY: "int16",
        lowerSouthwestCornerZ: "int16",
        sizeX: "int16",
        sizeY: "int16",
        sizeZ: "int16",
        name: "string",
      },
      key: ["id"],
    },
    Builds: {
      schema: {
        id: "bytes32",
        name: "string",
        objectTypeIds: "uint8[]",
        relativePositionsX: "int16[]",
        relativePositionsY: "int16[]",
        relativePositionsZ: "int16[]",
      },
      key: ["id"],
    },
    BuildsWithPos: {
      schema: {
        id: "bytes32",
        baseWorldCoordX: "int16",
        baseWorldCoordY: "int16",
        baseWorldCoordZ: "int16",
        name: "string",
        objectTypeIds: "uint8[]",
        relativePositionsX: "int16[]",
        relativePositionsY: "int16[]",
        relativePositionsZ: "int16[]"
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
