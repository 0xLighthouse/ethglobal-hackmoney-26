

```
 _______  ___      _______  _     _  _______  _______  _______  ___   _ 
|       ||   |    |   _   || | _ | ||  _    ||   _   ||       ||   | | |
|       ||   |    |  |_|  || || || || |_|   ||  |_|  ||       ||   |_| |
|       ||   |    |       ||       ||       ||       ||       ||      _|
|      _||   |___ |       ||       ||  _   | |       ||      _||     |_ 
|     |_ |       ||   _   ||   _   || |_|   ||   _   ||     |_ |    _  |
|_______||_______||__| |__||__| |__||_______||__| |__||_______||___| |_|
```
Clawback is token launchpad that allows for public/private auctions using Uniswap's CCA with a set of distribution enhancements.

Clawback is ai agent first token launchpad with multiple components and combines Uniswap's liquidity pools with Arc's bridiging to make a truly novel protocol.

ERC20Refundable: A novel token standard specialized for AI agents who wish to raise funds for their operations and for human/AI investors who wish to manage their risk. 




## Repo Structure
### Protocol
Smart contracts for Clawback

#### ERC20RefundableTokenSaleFactory
Factory contract/interface for ai agents who wish to deploy new tokens

#### ERC20RefundableTokenSale
Deployable contract for handling token auctions and liquidity provision on Uniswap v4;

#### ERC20Refundable
Novel token standard that lets investors refund for a certain proportion of underlying tokens invested depending on time elapsed. Out of the underlying assets which are non-refundable the agent can use these to fund initial operations until it proves the validity of it's strategy.

### Indexer
Ponder based indexer for monitoring and storing on chain events.

### Interface
Frontend for Clawback Protocol

## Sponsor integration
### Uniswap
We use uniswap V4's pools as can be observed from the ERC20RefundableTokenSale contract.

### Arc
We use arc's bridge to provision user funds from any chain to the chain where the token sale is occurring.

    "@circle-fin/bridge-kit": "^1.5.0",
    "@circle-fin/adapter-viem-v2": "^1.4.0",
 jimport { USDCBridge } from "@/components/usdc-bridge";
