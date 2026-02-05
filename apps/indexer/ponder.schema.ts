import { onchainTable } from "ponder";

export const token = onchainTable("tokens", (t) => ({
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

export const tokenSale = onchainTable("token_sales", (t) => ({
  id: t.text().primaryKey(),
  token: t.hex().notNull(),
  saleAmount: t.bigint().notNull(),
  purchasePrice: t.bigint().notNull(),
  saleStartBlock: t.bigint().notNull(),
  saleEndBlock: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.hex().notNull()
}));
