import { onchainTable } from "ponder";

export const refundableTokenDeployment = onchainTable("deployments", (t) => ({
  id: t.text().primaryKey(),
  token: t.hex().notNull(),
  deployer: t.hex().notNull(),
  beneficiary: t.hex().notNull(),
  name: t.text().notNull(),
  symbol: t.text().notNull(),
  maxSupply: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.hex().notNull()
}));
