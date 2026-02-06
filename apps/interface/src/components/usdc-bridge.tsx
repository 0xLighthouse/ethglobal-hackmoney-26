"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { createPublicClient, formatUnits, http } from "viem";
import { Button } from "@/components/ui/button";
import { useWeb3 } from "@/providers/web3";
import { CROSSCHAIN_USDC_CHAINS } from "@/config/constants";
import { BridgeChain } from "@circle-fin/bridge-kit";
import { useBridgeStore } from "@/stores/bridge";
import { NetworkIcon, TokenIcon } from "@web3icons/react/dynamic";

type UsdcBalanceRow = {
  id: string;
  name: string;
  balance: string;
  rawBalance: bigint;
  decimals: number;
  bridgeChain: BridgeChain;
  isTarget: boolean;
  isConfigured: boolean;
};

const BRIDGE_CHAIN_BY_ID: Record<string, BridgeChain> = {
  "base-sepolia": BridgeChain.Base_Sepolia,
  "ethereum-sepolia": BridgeChain.Ethereum_Sepolia,
  "optimism-sepolia": BridgeChain.Optimism_Sepolia,
  "arbitrum-sepolia": BridgeChain.Arbitrum_Sepolia,
};

const erc20BalanceAbi = [
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", internalType: "address", type: "address" }],
    outputs: [{ name: "", internalType: "uint256", type: "uint256" }],
    stateMutability: "view",
  },
] as const;

const BALANCE_TIMEOUT_MS = 2500;

export function USDCBridge() {
  const { walletClient, walletProvider, isInitialized } = useWeb3();
  const { bridge, status: bridgeStatus, error: bridgeError, activeChainId } = useBridgeStore();
  const [balances, setBalances] = useState<UsdcBalanceRow[]>([]);
  const [balanceStatus, setBalanceStatus] = useState<"idle" | "loading" | "error">("idle");
  const fetchIdRef = useRef(0);

  const configuredChains = useMemo(() => {
    return CROSSCHAIN_USDC_CHAINS.map((chain) => ({
      ...chain,
      isConfigured: Boolean(chain.rpcUrl && chain.usdcAddress),
    }));
  }, []);

  const fetchBalances = async () => {
      const fetchId = ++fetchIdRef.current;
      console.log("[USDCBridge] Fetching balances...");
      setBalanceStatus("loading");
      try {
        if (!walletClient || !isInitialized) {
          setBalances([]);
          if (fetchId === fetchIdRef.current) {
            setBalanceStatus("idle");
          }
          return;
        }

        const [account] = await walletClient.getAddresses();
        if (!account) {
          setBalances([]);
          if (fetchId === fetchIdRef.current) {
            setBalanceStatus("idle");
          }
          return;
        }

        console.log("[USDCBridge] Fetching balances for", configuredChains.length, "chains...");
        const rows = await Promise.all(
          configuredChains.map(async (chain) => {
            const bridgeChain = BRIDGE_CHAIN_BY_ID[chain.id] ?? BridgeChain.Base_Sepolia;
            if (!chain.isConfigured) {
              return {
                id: chain.id,
                name: chain.name,
                balance: "—",
                rawBalance: 0n,
                decimals: 6,
                bridgeChain,
                isTarget: Boolean(chain.isTarget),
                isConfigured: false,
              } satisfies UsdcBalanceRow;
            }
            try {
              const client = createPublicClient({
                transport: http(chain.rpcUrl),
              });

              const withTimeout = async <T,>(promise: Promise<T>) => {
                return await Promise.race([
                  promise,
                  new Promise<T>((_, reject) =>
                    setTimeout(() => reject(new Error("timeout")), BALANCE_TIMEOUT_MS)
                  ),
                ]);
              };

              const rawBalance = await withTimeout(
                client.readContract({
                  address: chain.usdcAddress as `0x${string}`,
                  abi: erc20BalanceAbi,
                  functionName: "balanceOf",
                  args: [account],
                })
              );

              console.log("[USDCBridge] Balance for", chain.name, formatUnits(rawBalance, 6));

              return {
                id: chain.id,
                name: chain.name,
                balance: formatUnits(rawBalance, 6),
                rawBalance,
                decimals: 6,
                bridgeChain,
                isTarget: Boolean(chain.isTarget),
                isConfigured: true,
              } satisfies UsdcBalanceRow;
            } catch {
              return {
                id: chain.id,
                name: chain.name,
                balance: "—",
                rawBalance: 0n,
                decimals: 6,
                bridgeChain,
                isTarget: Boolean(chain.isTarget),
                isConfigured: true,
              } satisfies UsdcBalanceRow;
            }
          })
        );

        setBalances(rows.sort((a, b) => a.name.localeCompare(b.name)));
        if (fetchId === fetchIdRef.current) {
          setBalanceStatus("idle");
        }
      } catch {
        if (fetchId === fetchIdRef.current) {
          setBalanceStatus("error");
        }
      }
    };

  useEffect(() => {
    fetchBalances();
  }, [configuredChains, walletClient, isInitialized]);

  return (
    <div className="mt-8 rounded-2xl border border-gray-200 bg-gray-50 p-5">
      <div className="flex items-center justify-between">
        <div className="text-sm font-semibold text-gray-900">USDC balances</div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={fetchBalances}
            className="text-[11px] font-semibold text-gray-500 hover:text-gray-700"
            disabled={balanceStatus === "loading"}
          >
            Refresh
          </button>
          <div className="text-[11px] font-medium text-gray-400">Bridge to Base Sepolia</div>
        </div>
      </div>
      <div className="mt-3 space-y-2 text-sm text-gray-600">
        {balanceStatus === "loading" && (
          <div className="rounded-xl border border-dashed border-gray-200 bg-white px-3 py-2 text-xs text-gray-500">
            Loading balances…
          </div>
        )}
        {balanceStatus === "error" && (
          <div className="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-600">
            Failed to load balances.
          </div>
        )}
        {balanceStatus === "idle" && balances.length === 0 && (
          <div className="rounded-xl border border-dashed border-gray-200 bg-white px-3 py-2 text-xs text-gray-500">
            Connect a wallet to see balances.
          </div>
        )}
        {bridgeError && (
          <div className="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-600">
            {bridgeError}
          </div>
        )}
        {balances.map((row) => (
          <div key={row.id} className="flex items-center justify-between rounded-xl bg-white px-3 py-2">
            <div className="flex items-center gap-2">
              <div className="flex items-center gap-1">
                <TokenIcon symbol="USDC" size={18} variant="branded" className="rounded-full" />
                <NetworkIcon name={row.name} size={18} variant="branded" className="rounded-full" />
              </div>
              <span className="font-medium text-gray-900">{row.name}</span>
              {row.isTarget && (
                <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] font-semibold text-emerald-700">
                  Target
                </span>
              )}
            </div>
            <div className="flex items-center gap-2">
              <span className={`tabular-nums ${row.isConfigured ? "text-gray-900" : "text-gray-400"}`}>
                {row.balance}
              </span>
              {!row.isTarget && (
                <Button
                  variant="outline"
                  size="sm"
                  className="h-8 rounded-full px-3 text-xs text-gray-500"
                  disabled={
                    !row.isConfigured ||
                    row.rawBalance <= 0n ||
                    bridgeStatus === "preparing" ||
                    bridgeStatus === "bridging"
                  }
                  onClick={() => {
                    const amountToBridge = formatUnits(row.rawBalance, row.decimals);
                    bridge({
                      provider: walletProvider,
                      fromChain: row.bridgeChain,
                      toChain: BridgeChain.Base_Sepolia,
                      amount: amountToBridge,
                      chainId: row.id,
                    });
                  }}
                >
                  {activeChainId === row.id && bridgeStatus !== "idle" ? "Bridging..." : "Bridge"}
                </Button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
