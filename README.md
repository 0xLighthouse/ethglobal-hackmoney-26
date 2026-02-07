# Clawback: Agent-Native Refundable Token Sales

A protocol that enables agents to launch tokens with programmable refund mechanisms, creating performance-coupled capital raising without centralized gatekeepers.

## Overview

Clawback lets agents:

- **Self-issue capital** through token sales using USDC as their funding asset.
- **Run continuous fundraising** across multiple sale windows without redeployment
- **Encode trust on-chain** through transparent, time-decaying refund rights

**Key innovation**: Buyers can return tokens and recover funds if the agent underperforms. Refund rights decay over time, unlocking capital for agents as they execute.

## How It Works

1. **Token Creation**
   100% of supply is minted to the contract (not the agent), ensuring all tokens are subject to the refund mechanism

2. **Sale Configuration**
   Each sale window defines:
   - **Sale period**: `saleStartBlock` → `saleEndBlock`
   - **Initial refund rate**: `refundableBpsAtStart` (e.g., 8000 = 80% refundable)
   - **Decay schedule**: `refundableDecayStartBlock` → `refundableDecayEndBlock`

3. **Purchase Flow**
   Buyers receive tokens plus embedded refund rights that decay over the configured window

4. **Capital Release**
   `claimableFunds()` releases funding to the beneficiary as refund obligations decrease

5. **Transferability**
   Tokens and their refund rights transfer together, maintaining the refund mechanism through secondary markets

## Architecture

```
ERC20RefundableTokenSaleFactory
  └── Creates and indexes agent token-sale contracts

ERC20RefundableTokenSale
  ├── Sale lifecycle management
  │   ├── createSale()
  │   ├── purchase()
  │   └── endSale()
  └── Optional Uniswap v4 liquidity seeding

ERC20Refundable
  ├── ERC-20 token implementation
  ├── Time-decaying refund rights
  └── Beneficiary fund claims

TokenLiquidity (library)
  └── Uniswap v4 pool creation and liquidity helpers
```

## Use Cases

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

## Getting Started

[Add installation and usage instructions here]

## License

[Add license information]

---

**Net Effect**: This protocol creates a better funding primitive for agentic systems by giving agents recurring access to capital while maintaining a credible, on-chain exit path for buyers when performance diverges from expectations.

## Faucets

- USDC <https://faucet.circle.com/>
