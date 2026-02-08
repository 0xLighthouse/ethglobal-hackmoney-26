import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";

/**
 * https://wagmi.sh/cli/api/plugins/foundry
 */
export default defineConfig([
  {
    out: "packages/abis/refundable-token-sale-factory.ts",
    plugins: [
      foundry({
        project: "apps/protocol",
        include: ["ERC20RefundableTokenSaleFactory.sol/**"]
      })
    ]
  },
  {
    out: "packages/abis/refundable-token-sale.ts",
    plugins: [
      foundry({
        project: "apps/protocol",
        include: ["ERC20RefundableTokenSale.sol/**", "ERC20RefundableTokenSaleFactory.sol/**"]
      })
    ]
  }
]);
