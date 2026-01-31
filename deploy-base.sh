#!/bin/bash

# Deploy to Base Sepolia Testnet
echo "🚀 Deploying to Base Sepolia Testnet..."

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY environment variable not set"
    exit 1
fi

# Clean cache and broadcast folders before deployment
echo "🧹 Cleaning cache and broadcast folders..."
rm -rf cache
rm -rf broadcast
echo "✅ Cache and broadcast folders cleaned"

forge script script/DeployMultiChain.s.sol:DeployMultiChainScript \
    --rpc-url base_sepolia \
    --broadcast \
    --verify \
    --delay 30 \
    --gas-estimate-multiplier 130 \
    -vvvv

echo "✅ Base Sepolia deployment completed!"
echo "📝 Please copy the environment variables from the output above to your .env.local file"