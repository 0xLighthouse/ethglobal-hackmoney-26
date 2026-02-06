import { baseSepolia, sepolia, optimismSepolia, arbitrumSepolia } from "viem/chains";


export const BASE_SEPOLIA_FACTORY_ADDRESS =
  (process.env.NEXT_PUBLIC_FACTORY_ADDRESS as `0x${string}` | undefined) ??
  "0xAA4c01f7B2627a227B257378C73BC52Abf74e71e";


// TODO: For now just use USDC on Base Sepolia
export const BASE_SEPOLIA_FUNDING_TOKEN_ADDRESS =
  (process.env.NEXT_PUBLIC_FUNDING_TOKEN_ADDRESS as `0x${string}` | undefined) ??
  "0x036CbD53842c5426634e7929541eC2318f3dCF7e";

type CrosschainUsdcConfig = {
  id: string;
  chainId: number;
  rpcUrl: string;
  name: string;
  usdcAddress: `0x${string}` | "";
  isTarget?: boolean;
};

// https://developers.circle.com/stablecoins/usdc-contract-addresses#testnet
export const CROSSCHAIN_USDC_CHAINS: CrosschainUsdcConfig[] = [
  {
    id: "base-sepolia",
    name: baseSepolia.name,
    chainId: baseSepolia.id,
    rpcUrl: process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC_URL ?? "https://sepolia.base.org",
    usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
    isTarget: true,
  },
  {
    id: "ethereum-sepolia",
    name: sepolia.name,
    chainId: sepolia.id,
    rpcUrl: process.env.NEXT_PUBLIC_ETHEREUM_SEPOLIA_RPC_URL ?? "https://ethereum-sepolia.gateway.tatum.io",
    usdcAddress: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
  },
  {
    id: "optimism-sepolia",
    name: optimismSepolia.name,
    chainId: optimismSepolia.id,
    rpcUrl: process.env.NEXT_PUBLIC_OPTIMISM_SEPOLIA_RPC_URL ?? "https://sepolia.optimism.io",
    usdcAddress: '0x5fd84259d66Cd46123540766Be93DFE6D43130D7'
  },
  {
    id: "arbitrum-sepolia",
    name: arbitrumSepolia.name,
    chainId: arbitrumSepolia.id,
    rpcUrl: process.env.NEXT_PUBLIC_ARBITRUM_SEPOLIA_RPC_URL ?? "https://sepolia-rollup.arbitrum.io/rpc",
    usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
  }
];
