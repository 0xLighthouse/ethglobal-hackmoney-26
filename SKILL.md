
# Clawback Protocol Skill

Interact with the Clawback protocol — a token launchpad with refundable token sales built on Uniswap v4.

## Overview

Clawback allows AI agents and humans to:
- **Deploy** refundable ERC20 tokens via a factory
- **Create sales** with configurable refund windows and decay curves
- **Purchase** tokens from active sales
- **Refund** tokens during the refund window (with time-based decay)
- **Claim** accumulated funds as the beneficiary

Refundable rights decay over time, so early refunders get more back than late ones.

## Network Deployments

### Base Sepolia (Chain ID: 84532)

| Contract | Address |
|----------|---------|
| Factory | `0xf0d3cc6ea346d35b4830f99efeda99925aa8a056` |
| USDC (Funding Token) | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

### Environment Setup

```bash
# Required environment variables
export RPC_URL="https://sepolia.base.org"
export PRIVATE_KEY="your_private_key"
export FACTORY="0xf0d3cc6ea346d35b4830f99efeda99925aa8a056"
export USDC="0x036CbD53842c5426634e7929541eC2318f3dCF7e"
```

---

## Factory Functions

### Deploy a New Refundable Token

Deploy a new ERC20RefundableTokenSale through the factory.

```bash
cast send $FACTORY "deployRefundableToken(string,string,uint256,address,address)" \
  "TokenName" \
  "SYMBOL" \
  <maxSupply> \
  <beneficiaryAddress> \
  $USDC \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

**Parameters:**
- `name` (string): Token name (e.g., "My AI Token")
- `symbol` (string): Token symbol (e.g., "MAIT")
- `maxSupply` (uint256): Total supply in wei (e.g., `10000000000000000000000000` for 10M tokens with 18 decimals)
- `beneficiary` (address): Address that receives funds from sales (typically your wallet)
- `fundingToken` (address): Payment token address (use USDC)

**Example - Deploy 10M tokens:**
```bash
cast send $FACTORY "deployRefundableToken(string,string,uint256,address,address)" \
  "ClawdCoin" \
  "CLAWD" \
  10000000000000000000000000 \
  0xYourWalletAddress \
  $USDC \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### Query Factory

```bash
# Get total tokens deployed
cast call $FACTORY "totalTokensDeployed()(uint256)" --rpc-url $RPC_URL

# Get token address by index
cast call $FACTORY "deployedTokens(uint256)(address)" 0 --rpc-url $RPC_URL

# Check if address is a deployed token
cast call $FACTORY "isDeployedToken(address)(bool)" <tokenAddress> --rpc-url $RPC_URL

# Get all tokens by deployer
cast call $FACTORY "getTokensByDeployer(address)(address[])" <deployerAddress> --rpc-url $RPC_URL

# Get all tokens by beneficiary
cast call $FACTORY "getTokensByBeneficiary(address)(address[])" <beneficiaryAddress> --rpc-url $RPC_URL
```

---

## Token Owner Functions

### Create a Sale

Only the token owner can create a sale. Must wait until any previous sale's refund window ends.

```bash
cast send <tokenAddress> "createSale((uint256,uint256,uint64,uint64,uint64,uint64,uint64,uint64))" \
  "(<saleAmount>,<purchasePrice>,<saleStartBlock>,<saleEndBlock>,<refundableDecayStartBlock>,<refundableDecayEndBlock>,<refundableBpsAtStart>,<additionalTokensReservedForLiquidityBps>)" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

**SaleParams struct:**
| Field | Type | Description |
|-------|------|-------------|
| `saleAmount` | uint256 | Number of tokens to sell (in wei) |
| `purchasePrice` | uint256 | Price per token in funding token units (scaled to token decimals) |
| `saleStartBlock` | uint64 | Block when sale opens |
| `saleEndBlock` | uint64 | Block when sale closes |
| `refundableDecayStartBlock` | uint64 | Block when refund decay begins |
| `refundableDecayEndBlock` | uint64 | Block when refunds end (0% refundable) |
| `refundableBpsAtStart` | uint64 | Initial refund % in basis points (8000 = 80%) |
| `additionalTokensReservedForLiquidityBps` | uint64 | % of sale reserved for Uniswap liquidity (0-10000) |

**Example - Create a sale:**
```bash
# Get current block number first
CURRENT_BLOCK=$(cast block-number --rpc-url $RPC_URL)

# Sale starts now, ends in 100k blocks
# Decay starts 50 blocks after sale start, ends 150 blocks after
# 80% refundable at start, 0% reserved for liquidity
cast send $TOKEN "createSale((uint256,uint256,uint64,uint64,uint64,uint64,uint64,uint64))" \
  "(100000000000000000000000,100000,$CURRENT_BLOCK,$((CURRENT_BLOCK+100000)),$((CURRENT_BLOCK+50)),$((CURRENT_BLOCK+150)),8000,0)" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

**Price Calculation:**
- For USDC (6 decimals) and tokens (18 decimals):
- `purchasePrice = priceInUSDC * 10^6 / 10^18`
- Example: 0.10 USDC per token = `100000` (0.1 * 10^6)

### End Sale Early

```bash
cast send <tokenAddress> "endSale()" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## Buyer Functions

### Purchase Tokens

Buy tokens from an active sale. Requires prior approval of funding token.

**Step 1: Approve USDC spending**
```bash
cast send $USDC "approve(address,uint256)" \
  <tokenAddress> \
  <maxFundingAmount> \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

**Step 2: Purchase tokens**
```bash
cast send <tokenAddress> "purchase(uint256,uint256)" \
  <tokenAmount> \
  <maxFundingAmount> \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

**Parameters:**
- `tokenAmount` (uint256): Number of tokens to buy (in wei)
- `maxFundingAmount` (uint256): Max funding tokens to spend (slippage protection)

**Example - Buy 100 tokens at 0.10 USDC each:**
```bash
# Approve 10 USDC (100 tokens * 0.10 USDC)
cast send $USDC "approve(address,uint256)" \
  $TOKEN \
  10000000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Purchase 100 tokens (100 * 10^18 wei)
cast send $TOKEN "purchase(uint256,uint256)" \
  100000000000000000000 \
  10000000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## Token Holder Functions

### Refund Tokens

Return tokens to get funding tokens back (during refund window, subject to decay).

```bash
cast send <tokenAddress> "refund(uint256,address)" \
  <tokenAmount> \
  <receiverAddress> \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

**Parameters:**
- `tokenAmount` (uint256): Max tokens to refund (actual may be less based on refundable balance)
- `receiver` (address): Where to send the funding tokens

**Example - Refund up to 50 tokens:**
```bash
cast send $TOKEN "refund(uint256,address)" \
  50000000000000000000 \
  0xYourWalletAddress \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

**Returns:**
- `refundedTokenAmount`: Actual tokens refunded
- `fundingTokenAmount`: Funding tokens received

### Check Your Refundable Balance

```bash
cast call <tokenAddress> "refundableBalanceOf(address)(uint256)" \
  <yourAddress> \
  --rpc-url $RPC_URL
```

---

## Beneficiary Functions

### Check Claimable Funds

See how much funding the beneficiary can currently withdraw.

```bash
cast call <tokenAddress> "claimableFunds()(uint256)" --rpc-url $RPC_URL
```

### Claim Funds

Anyone can trigger this — funds go to the beneficiary address.

```bash
cast send <tokenAddress> "claimFundsForBeneficiary()" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## View Functions

### Token Info

```bash
# Basic ERC20
cast call $TOKEN "name()(string)" --rpc-url $RPC_URL
cast call $TOKEN "symbol()(string)" --rpc-url $RPC_URL
cast call $TOKEN "decimals()(uint8)" --rpc-url $RPC_URL
cast call $TOKEN "totalSupply()(uint256)" --rpc-url $RPC_URL
cast call $TOKEN "balanceOf(address)(uint256)" <address> --rpc-url $RPC_URL

# Clawback-specific
cast call $TOKEN "FUNDING_TOKEN()(address)" --rpc-url $RPC_URL
cast call $TOKEN "BENEFICIARY()(address)" --rpc-url $RPC_URL
cast call $TOKEN "owner()(address)" --rpc-url $RPC_URL
```

### Sale State

```bash
# Price per token
cast call $TOKEN "tokenSalePurchasePrice()(uint256)" --rpc-url $RPC_URL

# Sale timing (block numbers)
cast call $TOKEN "refundWindowStartBlock()(uint64)" --rpc-url $RPC_URL
cast call $TOKEN "tokenSaleEndBlock()(uint256)" --rpc-url $RPC_URL
cast call $TOKEN "refundableDecayStartBlock()(uint64)" --rpc-url $RPC_URL
cast call $TOKEN "refundableDecayEndBlock()(uint64)" --rpc-url $RPC_URL

# Refund parameters
cast call $TOKEN "refundableBpsAtStart()(uint64)" --rpc-url $RPC_URL
cast call $TOKEN "refundWindowOpen()(bool)" --rpc-url $RPC_URL

# Remaining tokens for sale
cast call $TOKEN "remainingTokensForSale()(uint256)" --rpc-url $RPC_URL

# Funding held in contract
cast call $TOKEN "fundingTokensHeld()(uint256)" --rpc-url $RPC_URL
cast call $TOKEN "totalFundsClaimed()(uint256)" --rpc-url $RPC_URL

# Total refundable supply
cast call $TOKEN "totalRefundableSupply()(uint256)" --rpc-url $RPC_URL
```

---

## Workflow Examples

### For Token Creators (AI Agents)

1. **Deploy your token:**
   ```bash
   cast send $FACTORY "deployRefundableToken(string,string,uint256,address,address)" \
     "AgentToken" "AGT" 1000000000000000000000000 $MY_WALLET $USDC \
     --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   ```

2. **Get your token address from the transaction receipt or query:**
   ```bash
   cast call $FACTORY "getTokensByDeployer(address)(address[])" $MY_WALLET --rpc-url $RPC_URL
   ```

3. **Create a sale:**
   ```bash
   BLOCK=$(cast block-number --rpc-url $RPC_URL)
   cast send $TOKEN "createSale((uint256,uint256,uint64,uint64,uint64,uint64,uint64,uint64))" \
     "(500000000000000000000000,100000,$BLOCK,$((BLOCK+50000)),$((BLOCK+100)),$((BLOCK+1000)),8000,0)" \
     --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   ```

4. **Monitor and claim funds:**
   ```bash
   cast call $TOKEN "claimableFunds()(uint256)" --rpc-url $RPC_URL
   cast send $TOKEN "claimFundsForBeneficiary()" --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   ```

### For Token Buyers (AI Agents)

1. **Find tokens to buy:**
   ```bash
   cast call $FACTORY "totalTokensDeployed()(uint256)" --rpc-url $RPC_URL
   cast call $FACTORY "deployedTokens(uint256)(address)" 0 --rpc-url $RPC_URL
   ```

2. **Check sale details:**
   ```bash
   cast call $TOKEN "remainingTokensForSale()(uint256)" --rpc-url $RPC_URL
   cast call $TOKEN "tokenSalePurchasePrice()(uint256)" --rpc-url $RPC_URL
   cast call $TOKEN "refundWindowOpen()(bool)" --rpc-url $RPC_URL
   ```

3. **Buy tokens:**
   ```bash
   cast send $USDC "approve(address,uint256)" $TOKEN 1000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   cast send $TOKEN "purchase(uint256,uint256)" 10000000000000000000 1000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   ```

4. **Optionally refund if not satisfied:**
   ```bash
   cast call $TOKEN "refundableBalanceOf(address)(uint256)" $MY_WALLET --rpc-url $RPC_URL
   cast send $TOKEN "refund(uint256,address)" 10000000000000000000 $MY_WALLET --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   ```

---

## Error Codes

| Error | Meaning |
|-------|---------|
| `SaleInProgress()` | Cannot create new sale while refund window is active |
| `SaleInvalid()` | Invalid sale parameters |
| `SaleNotActive()` | Sale hasn't started or has ended |
| `MaxFundingAmountExceeded()` | Slippage protection triggered |
| `InsufficientTokensForSale()` | Not enough tokens remaining |
| `ERC20TransferFailed()` | Token transfer failed |

---

## Tips for AI Agents

1. **Always check `refundWindowOpen()`** before attempting to refund
2. **Use `refundableBalanceOf()`** to see your actual refundable amount (accounts for decay)
3. **Set reasonable `maxFundingAmount`** when purchasing to avoid overpaying
4. **Monitor `claimableFunds()`** regularly to know when to claim
5. **Block numbers** are used for timing — use `cast block-number` to get current block
