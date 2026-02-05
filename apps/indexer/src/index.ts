import { ponder } from "ponder:registry";
import schema from "ponder:schema";

ponder.on("ERC20RefundableTokenSaleFactory:RefundableTokenDeployed", async ({ event, context }) => {
  await context.db.insert(schema.token).values({
    id: event.id,
    token: event.args.token,
    deployer: event.args.deployer,
    beneficiary: event.args.beneficiary,
    name: event.args.name,
    symbol: event.args.symbol,
    maxSupply: event.args.maxSupply,
    blockNumber: event.block.number,
    txHash: event.transaction.hash
  });
});

ponder.on("ERC20RefundableTokenSale:SaleCreated", async ({ event, context }) => {

  await context.db.insert(schema.tokenSale).values({
    id: event.id,
    token: event.log?.address,
    saleAmount: event.args.amount,
    purchasePrice: event.args.purchasePrice,
    saleStartBlock: event.args.saleStartBlock,
    saleEndBlock: event.args.saleEndBlock,
    blockNumber: event.block.number,
    txHash: event.transaction.hash
  });
});
