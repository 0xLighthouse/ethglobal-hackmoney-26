import { createConfig } from "ponder";
import { baseSepolia } from "viem/chains";

import { ERC20RefundableTokenSaleFactoryABI, ERC20RefundableTokenSaleABI } from "@repo/abis";
import { factory } from "ponder";
import { resolveDeployment } from "./src/lib/resolveDeployment";

const rpcUrl = process.env.BASE_SEPOLIA_RPC_URL;

if (!rpcUrl) {
  throw new Error("Missing BASE_SEPOLIA_RPC_URL env var.");
}

const factoryDeployment = resolveDeployment(
  "ERC20RefundableTokenSaleFactory",
  "apps/protocol/broadcast/DeployFactory.s.sol/84532/run-latest.json"
);

const refundableTokenDeployedEvent = ERC20RefundableTokenSaleFactoryABI.find(
  (o) => o.type === "event" && o.name === "RefundableTokenDeployed"
);

if (!refundableTokenDeployedEvent) {
  throw new Error("RefundableTokenDeployed event not found in factory ABI.");
}

export default createConfig({
  chains: {
    baseSepolia: {
      id: baseSepolia.id,
      rpc: rpcUrl,
      // pollingInterval: 30_000
    }
  },
  contracts: {
    ERC20RefundableTokenSaleFactory: {
      chain: "baseSepolia",
      abi: ERC20RefundableTokenSaleFactoryABI,
      address: factoryDeployment.address,
      startBlock: factoryDeployment.startBlock
    },
    ERC20RefundableTokenSale: {
      chain: "baseSepolia",
      abi: ERC20RefundableTokenSaleABI,
      startBlock: factoryDeployment.startBlock,
      address: factory({
        address: factoryDeployment.address,
        event: refundableTokenDeployedEvent,
        parameter: "token"
      })
    },
  }
});
