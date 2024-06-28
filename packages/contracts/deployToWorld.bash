#!/bin/bash

chainId="31337" # Default to dev mode chain ID
rpcUrl="http://127.0.0.1:8545"  # Default to dev mode URL

# Loop through all arguments to check for the --prod flag
if [ "$NODE_ENV" = "testnet" ]; then
  rpcUrl="https://rpc.garnetchain.com"
  chainId="17069"
elif [ "$NODE_ENV" = "mainnet" ]; then
  rpcUrl="https://rpc.redstonechain.com"
  chainId="690"
fi

echo "Using RPC: $rpcUrl"
echo "Using Chain Id: $chainId"

# Extract worldAddress using awk
worldAddress=$(awk -v id="$chainId" -F'"' '$2 == id {getline; print $4}' ../../../biomes-contracts/packages/world/worlds.json)

echo "Using WorldAddress: $worldAddress"

command="pnpm mud deploy --worldAddress=$worldAddress --alwaysRunPostDeploy=true"

echo "Running script: $command"

eval "$command"