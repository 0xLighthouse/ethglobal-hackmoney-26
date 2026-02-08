"use client";

import { create } from "zustand";
import { BridgeKit, type BridgeChainIdentifier, BridgeChain } from "@circle-fin/bridge-kit";
import { createViemAdapterFromProvider } from "@circle-fin/adapter-viem-v2";
import type { EIP1193Provider } from "viem";
import { arbitrumSepolia, baseSepolia, optimismSepolia, sepolia } from "viem/chains";

type BridgeStatus = "idle" | "preparing" | "bridging" | "success" | "error";

type BridgeResult = {
  transferId?: string;
  txHash?: string;
};

type BridgeState = {
  status: BridgeStatus;
  error: string | null;
  activeChainId: string | null;
  lastResult: BridgeResult | null;
  bridge: (params: {
    provider: EIP1193Provider | null;
    fromChain: BridgeChainIdentifier;
    toChain: BridgeChainIdentifier;
    amount: string;
    chainId: string;
  }) => Promise<void>;
  reset: () => void;
};

const kit = new BridgeKit();

const CHAIN_BY_BRIDGE: Record<BridgeChain, { id: number; name: string; rpcUrls: string[]; nativeCurrency: { name: string; symbol: string; decimals: number }; blockExplorers?: { url: string } }> = {
  [BridgeChain.Ethereum_Sepolia]: {
    id: sepolia.id,
    name: sepolia.name,
    rpcUrls: sepolia.rpcUrls.default.http,
    nativeCurrency: sepolia.nativeCurrency,
    blockExplorers: sepolia.blockExplorers?.default,
  },
  [BridgeChain.Base_Sepolia]: {
    id: baseSepolia.id,
    name: baseSepolia.name,
    rpcUrls: baseSepolia.rpcUrls.default.http,
    nativeCurrency: baseSepolia.nativeCurrency,
    blockExplorers: baseSepolia.blockExplorers?.default,
  },
  [BridgeChain.Optimism_Sepolia]: {
    id: optimismSepolia.id,
    name: optimismSepolia.name,
    rpcUrls: optimismSepolia.rpcUrls.default.http,
    nativeCurrency: optimismSepolia.nativeCurrency,
    blockExplorers: optimismSepolia.blockExplorers?.default,
  },
  [BridgeChain.Arbitrum_Sepolia]: {
    id: arbitrumSepolia.id,
    name: arbitrumSepolia.name,
    rpcUrls: arbitrumSepolia.rpcUrls.default.http,
    nativeCurrency: arbitrumSepolia.nativeCurrency,
    blockExplorers: arbitrumSepolia.blockExplorers?.default,
  },
};

const toHexChainId = (chainId: number) => `0x${chainId.toString(16)}`;

const ensureChain = async (provider: EIP1193Provider, bridgeChain: BridgeChain) => {
  const chain = CHAIN_BY_BRIDGE[bridgeChain];
  if (!chain) return;
  try {
    await provider.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: toHexChainId(chain.id) }],
    });
  } catch (err) {
    const error = err as { code?: number };
    if (error?.code !== 4902) {
      throw err;
    }
    await provider.request({
      method: "wallet_addEthereumChain",
      params: [
        {
          chainId: toHexChainId(chain.id),
          chainName: chain.name,
          nativeCurrency: chain.nativeCurrency,
          rpcUrls: chain.rpcUrls,
          blockExplorerUrls: chain.blockExplorers?.url ? [chain.blockExplorers.url] : [],
        },
      ],
    });
  }
};

export const useBridgeStore = create<BridgeState>()((set) => ({
  status: "idle",
  error: null,
  activeChainId: null,
  lastResult: null,

  bridge: async ({ provider, fromChain, toChain, amount, chainId }) => {
    if (!provider) {
      set({ status: "error", error: "Connect a wallet to bridge.", activeChainId: null });
      return;
    }

    const normalizedAmount = amount?.trim();
    if (!normalizedAmount || Number(normalizedAmount) <= 0) {
      set({ status: "error", error: "Bridge amount must be greater than zero.", activeChainId: null });
      return;
    }

    set({ status: "preparing", error: null, activeChainId: chainId, lastResult: null });

    try {
      await ensureChain(provider, fromChain as BridgeChain);
      const adapter = await createViemAdapterFromProvider({
        provider,
        capabilities: {
          addressContext: "user-controlled",
        },
      });

      set({ status: "bridging" });

      const result = await kit.bridge({
        from: { adapter, chain: fromChain },
        to: { adapter, chain: toChain },
        amount: normalizedAmount,
      });

      set({
        status: "success",
        lastResult: {
          transferId: (result as { transferId?: string }).transferId,
          txHash: (result as { txHash?: string }).txHash,
        },
      });
    } catch (err) {
      set({
        status: "error",
        error: err instanceof Error ? err.message : "Bridge failed.",
      });
    } finally {
      set({ activeChainId: null });
    }
  },

  reset: () => {
    set({ status: "idle", error: null, activeChainId: null, lastResult: null });
  },
}));
