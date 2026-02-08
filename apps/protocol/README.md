# Foundry

```sh
# Start local RPC
anvil --block-time 5

# Deploy Libs
forge script script/DeployTokenLiquidity.s.sol:DeployTokenLiquidity \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast

# Deploy factory + linked lib
forge script script/DeployFactory.s.sol \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verify \
    --libraries src/libraries/TokenLiquidity.sol:TokenLiquidity:0xBFC76C271d492c9E5EDB495F733E6ea08F3054f3

# Create base sale
forge script script/CreateToken.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast

# Buy tokens
forge script script/BuyTokens.s.sol:BuyTokens --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```
