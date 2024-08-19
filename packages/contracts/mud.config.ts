import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  // Note: this is required as the Biome world is deployed with this
  deploy: {
    upgradeableWorldImplementation: true,
  },
  namespace: "vaultguard",
  tables: {
    GameMetadata: {
      schema: {
        vaultChestCoordX: "int16",
        vaultChestCoordY: "int16",
        vaultChestCoordZ: "int16",
      },
      key: [],
    },
    VaultTools: {
      schema: {
        toolEntityId: "bytes32",
        owner: "address",
      },
      key: ["toolEntityId"]
    },
    VaultObjects: {
      schema: {
        owner: "address",
        objectTypeId: "uint8",
        count: "uint16",
      },
      key: ["owner", "objectTypeId"]
    },
    Metadata: {
      schema: {
        experienceAddress: "address",
      },
      key: [],
    },
  },
});
