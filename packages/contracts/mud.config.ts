import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "buildanomics",
  tables: {
    PlayerMetadata: {
      schema: {
        player: "address",
        earned: "uint256"
      },
      key: ["player"]
    },
    BuildIds: {
      schema: {
        value: "uint256",
      },
      key: [],
      codegen: {
        storeArgument: true,
      },
    },
    BuildMetadata: {
      schema: {
        buildId: "bytes32",
        submissionPrice: "uint256",
        builders: "address[]",
        locationsX: "int16[]",
        locationsY: "int16[]",
        locationsZ: "int16[]",
      },
      key: ["buildId"]
    },
    Builder: {
      schema: {
        x: "int16",
        y: "int16",
        z: "int16",
        builder: "address",
      },
      key: ["x", "y", "z"]
    },
    Metadata: {
      schema: {
        experienceAddress: "address",
      },
      key: [],
    },
  },
});
