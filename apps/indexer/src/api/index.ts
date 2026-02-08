import { db } from "ponder:api";
import schema from "ponder:schema";
import { desc, graphql, sql } from "ponder";
import { Hono } from "hono";
import { createPublicClient, http } from "viem";
import { baseSepolia } from "viem/chains";

const app = new Hono();
const rpcUrl = process.env.BASE_SEPOLIA_RPC_URL;
const publicClient = rpcUrl
  ? createPublicClient({
    chain: baseSepolia,
    transport: http(rpcUrl)
  })
  : null;
const BLOCK_TIME_SECONDS = 2;

app.get("/", (c) => c.text("Indexer running"));
app.use("/graphql", graphql({ db, schema }));
app.get("/sale-details", async (c) => {
  if (!publicClient) {
    return c.json({ error: "Missing BASE_SEPOLIA_RPC_URL env var." }, 500);
  }

  const sales = await db
    .select()
    .from(schema.tokenSale)
    .orderBy(desc(schema.tokenSale.blockNumber));
  const saleByToken = new Map<string, (typeof sales)[number]>();
  for (const sale of sales) {
    const token = sale.token.toLowerCase();
    if (!saleByToken.has(token)) {
      saleByToken.set(token, sale);
    }
  }

  const activity = await db
    .select({
      token: schema.tokenSaleActivity.token,
      tokensPurchased: sql`sum(case when ${schema.tokenSaleActivity.kind} = 'purchase' then ${schema.tokenSaleActivity.tokenAmount} else 0 end)`,
      tokensRefunded: sql`sum(case when ${schema.tokenSaleActivity.kind} = 'refund' then ${schema.tokenSaleActivity.tokenAmount} else 0 end)`,
      fundingSpent: sql`sum(case when ${schema.tokenSaleActivity.kind} = 'purchase' then ${schema.tokenSaleActivity.fundingAmount} else 0 end)`,
      fundingRefunded: sql`sum(case when ${schema.tokenSaleActivity.kind} = 'refund' then ${schema.tokenSaleActivity.fundingAmount} else 0 end)`
    })
    .from(schema.tokenSaleActivity)
    .groupBy(schema.tokenSaleActivity.token);

  const activityByToken = new Map<string, (typeof activity)[number]>();
  for (const row of activity) {
    activityByToken.set(row.token.toLowerCase(), row);
  }

  const latestBlockNumber = await publicClient.getBlockNumber();

  const items = Array.from(saleByToken.entries()).map(([token, sale]) => {
    const stats = activityByToken.get(token);
    const tokensPurchased = stats?.tokensPurchased
      ? BigInt(stats.tokensPurchased as bigint)
      : 0n;
    const tokensRefunded = stats?.tokensRefunded
      ? BigInt(stats.tokensRefunded as bigint)
      : 0n;
    const fundingSpent = stats?.fundingSpent ? BigInt(stats.fundingSpent as bigint) : 0n;
    const fundingRefunded = stats?.fundingRefunded
      ? BigInt(stats.fundingRefunded as bigint)
      : 0n;

    const tokensSold = tokensPurchased > tokensRefunded ? tokensPurchased - tokensRefunded : 0n;
    const fundingRaised =
      fundingSpent > fundingRefunded ? fundingSpent - fundingRefunded : 0n;
    const saleAmount = BigInt(sale.saleAmount);
    const remainingTokens = saleAmount > tokensSold ? saleAmount - tokensSold : 0n;
    const percentTokensRemaining =
      saleAmount > 0n ? Number((remainingTokens * 10000n) / saleAmount) / 100 : null;
    const blocksRemaining =
      sale.saleEndBlock > latestBlockNumber
        ? sale.saleEndBlock - latestBlockNumber
        : 0n;
    const closingInDays =
      sale.saleEndBlock > 0n
        ? Math.ceil((Number(blocksRemaining) * BLOCK_TIME_SECONDS) / 86_400)
        : null;

    return {
      token: sale.token,
      saleAmount: sale.saleAmount.toString(),
      purchasePrice: sale.purchasePrice.toString(),
      saleStartBlock: sale.saleStartBlock.toString(),
      saleEndBlock: sale.saleEndBlock.toString(),
      tokensSold: tokensSold.toString(),
      fundingRaised: fundingRaised.toString(),
      remainingTokens: remainingTokens.toString(),
      percentTokensRemaining,
      closingInDays
    };
  });

  return c.json({
    items,
    latestBlockNumber: latestBlockNumber.toString(),
    blockTimeSeconds: BLOCK_TIME_SECONDS
  });
});

export default app;
