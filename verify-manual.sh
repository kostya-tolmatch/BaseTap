#!/bin/bash

# Manual verification script for upgraded contracts
# Usage: ./verify-manual.sh <network> <contract_name>

NETWORK=$1
CONTRACT=$2

if [ "$NETWORK" == "base-sepolia" ]; then
  CHAIN_ID=84532
  RPC_URL=$BASE_SEPOLIA_RPC_URL
else
  CHAIN_ID=8453
  RPC_URL=$BASE_RPC_URL
fi

# Read implementation address from deployment JSON
IMPL_ADDR=$(jq -r ".${CONTRACT}.implementation" deployments/${NETWORK}.json)

if [ -z "$IMPL_ADDR" ] || [ "$IMPL_ADDR" == "null" ] || [ "$IMPL_ADDR" == "" ]; then
  echo "❌ No implementation address found for $CONTRACT on $NETWORK"
  exit 1
fi

echo "Verifying $CONTRACT implementation at $IMPL_ADDR on $NETWORK (chain $CHAIN_ID)..."

forge verify-contract $IMPL_ADDR \
  src/${CONTRACT}.sol:${CONTRACT} \
  --chain $CHAIN_ID \
  --etherscan-api-key $BASESCAN_API_KEY \
  --watch

echo "✅ Verification complete!"
