# Foundry

```sh
# Start local RPC
anvil --block-time 5

# Deploy factory
forge script script/DeployFactory.s.sol \
    --rpc-url <RPC_URL> \
    --broadcast \
    --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
    --verify


forge script script/DeployFactory.s.sol \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --verify
```
