import { ponder } from "ponder:registry";
import schema from "ponder:schema";

ponder.on("ERC20RefundableTokenSaleFactory:RefundableTokenDeployed", async ({ event, context }) => {
  await context.db.insert(schema.refundableTokenDeployment).values({
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
