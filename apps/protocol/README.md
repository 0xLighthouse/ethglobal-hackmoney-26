# Foundry

```sh
# Start local RPC
anvil --block-time 5

# Deploy factory
forge script script/DeployFactory.s.sol \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verify

# Create base sale
forge script script/DeployTokenSale.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```
