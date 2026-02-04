# Foundry

```sh
# Start local RPC
anvil --block-time 5

# Deploy factory
forge script script/DeployRefundableFactory.s.sol \
    --rpc-url $LOCAL_RPC \
    --broadcast \
    --private-key $TESTNET_DEPLOYER_PRIVATE_KEY
```
