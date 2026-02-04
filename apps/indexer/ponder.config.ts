import { createConfig } from "ponder";
import { http } from "viem";
import { baseSepolia } from "viem/chains";

import { ERC20RefundableTokenSaleFactoryABI } from "@repo/abis";
import { resolveDeployment } from "./src/lib/resolveDeployment";

const rpcUrl = process.env.BASE_SEPOLIA_RPC_URL;

if (!rpcUrl) {
  throw new Error("Missing BASE_SEPOLIA_RPC_URL env var.");
}

const factoryDeployment = resolveDeployment(
  "ERC20RefundableTokenSaleFactory",
  "apps/protocol/broadcast/DeployFactory.s.sol/84532/run-latest.json"
);


console.log('factoryDeployment');
console.log(factoryDeployment);

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
    }
  }
});
