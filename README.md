![logo](https://raw.githubusercontent.com/0xLighthouse/ethglobal-hackmoney-26/refs/heads/develop/clawback.svg)

```
 _______  ___      _______  _     _  _______  _______  _______  ___   _
|       ||   |    |   _   || | _ | ||  _    ||   _   ||       ||   | | |
|       ||   |    |  |_|  || || || || |_|   ||  |_|  ||       ||   |_| |
|       ||   |    |       ||       ||       ||       ||       ||      _|
|      _||   |___ |       ||       ||  _   | |       ||      _||     |_
|     |_ |       ||   _   ||   _   || |_|   ||   _   ||     |_ |    _  |
|_______||_______||__| |__||__| |__||_______||__| |__||_______||___| |_|

```
## Overview

Clawback lets agents:

- **Self-issue capital** through token sales using USDC as their funding asset, with automatic Uniswap pool creation and liquidity provisioning.
- **Run continuous fundraising** across multiple sale windows without redeployment
- **Encode trust on-chain** through transparent, time-decaying refund rights

**Key innovation**: Buyers can return tokens and recover funds if the agent underperforms. Refund rights decay over time, unlocking capital for agents as they execute.

## Repo Structure
- [`protocol`](./apps/protocol/): Smart contracts for Clawback

- [`interface`](./apps/interface/): Frontend for Clawback Protocol

- [`indexer`](./apps/indexer/): Ponder based indexer for monitoring and storing emitted events

## How It Works

1. **Token Creation:**

   The agent creates their own token through our factory, specifying the name and max supply. 100% of new tokens start out minted to the contract (not the agent), so humans can be assured there will be no surprises down the line.

2. **Sale Configuration:**

   The agent can now launch a token sale, and specify:
   - **Sale price**: The price of new tokens in USDC (e.g. 1000000 = $1 USDC per token)
   - **Initial refund rate**: `refundableBpsAtStart` (e.g., 8000 = 80% of tokens will start out refundable)
   - **Sale period**: The sale will be open from `saleStartBlock` and ending at `saleEndBlock` (denoted as block height). Unsold tokens will remain available to sell next time.
   - **Decay schedule**: Tokens are refundable immediately, and the initial refund rate will continue until `refundableDecayStartBlock`. Tokens will gradually convert to completely non-refundable by the time we reach `refundableDecayEndBlock` (denoted as block height).

   A new sale can be created as soon as the previous sale's refund window is closed.

3. **Purchase Flow:**

   Human buyers use our web interface to easily buy tokens. Because of Arc's bridge, their USDC can be on any chain and we will move it automatically. All tokens come with embedded refund rights that decay over the configured window. Refunds can be conducted through our interface or directly by calling `refund(tokenAmount, payee)` on the token contract.

4. **Capital Release:**

   `claimableFunds()` reports how much USDC is available for the agent to claim as refund obligations decrease.
   Anyone can call `claimFundsForBeneficiary()` to transfer all claimable funds to the beneficiary address set when the token was created.

5. **Transferability:**

   Tokens and their refund rights transfer together, following the refund window schedule, maintaining the refund mechanism through secondary markets.

## Architecture

```
ERC20Refundable
  ├── ERC-20 token implementation
  ├── Time-decaying refund rights
  │   ├── refund()
  │   ├── claimableFunds()
  │   └── claimFundsForBeneficiary()
  └── Beneficiary fund claims

ERC20RefundableTokenSale
  ├── Sale lifecycle management
  │   ├── createSale()
  │   ├── purchase()
  │   └── endSale()
  └── Optional Uniswap v4 liquidity seeding

ERC20RefundableTokenSaleFactory
  └── Creates and indexes agent token-sale contracts

TokenLiquidity (library)
  └── Uniswap v4 pool creation and liquidity helpers
```

## Benefits

**For Agents**

- Launch tokens without intermediaries
- Raise capital continuously across multiple windows
- Access funds progressively as refund obligations decay
- Bootstrap liquidity automatically through Uniswap v4

**For Token Buyers**

- Risk-managed participation with credible exit path
- Refund rights that transfer with tokens
- On-chain transparency of refund mechanics
- Reduced exposure to agent underperformance

## Why Programmable Clawbacks

Traditional token sales lock capital immediately, creating misaligned incentives. Clawback aligns agent incentives with execution:

- **Early stage**: High refundability (e.g., 80%) protects buyers, motivates agents
- **As execution progresses**: Decreasing refund rights unlock capital for the agent
- **Poor performance**: Increases redemptions instead of trapping buyers
- **Trust mechanism**: Refund terms are enforced by code, not promises

## Prize Tracks

### Uniswap v4 Agentic Finance
We enable agents to launch a token sale, wrapped around a Uniswap v4 pool. Liquidity is provisioned and added to the pool with every purchase, adjusted for current token price. 

### Arc - Chain Abstracted USDC Apps Using Arc as a Liquidity Hub
When a human participates in an agent's token sale, we detect the user's USDC balances across all chains and let them migrate funds to the current chain with one click. Gone are the days of seeing a sale you want to jump in to, and having to track down your funds to pay for it!

## Faucets

- USDC <https://faucet.circle.com/>


