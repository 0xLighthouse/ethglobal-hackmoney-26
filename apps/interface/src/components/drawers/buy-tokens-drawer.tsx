"use client";

import { Drawer } from "vaul";
import { useEffect, useMemo, useState, type CSSProperties } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { createPublicClient, formatUnits, http } from "viem";
import { useWeb3 } from "@/providers/web3";
import { CROSSCHAIN_USDC_CHAINS } from "@/config/constants";

type BuyTokensDrawerProps = {
  triggerLabel?: string;
  triggerClassName?: string;
  disabled?: boolean;
  tokenAddress: `0x${string}`;
  tokenSymbol?: string;
};

type UsdcBalanceRow = {
  id: string;
  name: string;
  balance: string;
  isTarget: boolean;
  isConfigured: boolean;
};

const erc20BalanceAbi = [
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", internalType: "address", type: "address" }],
    outputs: [{ name: "", internalType: "uint256", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "decimals",
    inputs: [],
    outputs: [{ name: "", internalType: "uint8", type: "uint8" }],
    stateMutability: "view",
  },
] as const;

export function BuyTokensDrawer({
  triggerLabel = "Buy Tokens",
  triggerClassName = "h-11 rounded-full px-5 text-sm font-semibold shadow-sm",
  disabled = false,
  tokenAddress,
  tokenSymbol = "Token",
}: BuyTokensDrawerProps) {
  const { walletClient, isInitialized } = useWeb3();
  const [open, setOpen] = useState(false);
  const [amount, setAmount] = useState("");
  const [balances, setBalances] = useState<UsdcBalanceRow[]>([]);
  const [balanceStatus, setBalanceStatus] = useState<"idle" | "loading" | "error">("idle");

  const configuredChains = useMemo(() => {
    return CROSSCHAIN_USDC_CHAINS.map((chain) => ({
      ...chain,
      isConfigured: Boolean(chain.rpcUrl && chain.usdcAddress),
    }));
  }, []);

  useEffect(() => {
    if (!open) return;
    const loadBalances = async () => {
      setBalanceStatus("loading");
      try {
        if (!walletClient || !isInitialized) {
          setBalances([]);
          setBalanceStatus("idle");
          return;
        }

        const [account] = await walletClient.getAddresses();
        if (!account) {
          setBalances([]);
          setBalanceStatus("idle");
          return;
        }

        const rows: UsdcBalanceRow[] = [];
        for (const chain of configuredChains) {
          if (!chain.isConfigured) {
            rows.push({
              id: chain.id,
              name: chain.name,
              balance: "—",
              isTarget: Boolean(chain.isTarget),
              isConfigured: false,
            });
            continue;
          }
          const client = createPublicClient({
            transport: http(chain.rpcUrl),
            chain: { id: chain.chainId, name: chain.name, nativeCurrency: { name: "", symbol: "", decimals: 18 }, rpcUrls: { default: { http: [chain.rpcUrl] } } },
          });

          const [rawBalance, decimals] = await Promise.all([
            client.readContract({
              address: chain.usdcAddress as `0x${string}`,
              abi: erc20BalanceAbi,
              functionName: "balanceOf",
              args: [account],
            }),
            client.readContract({
              address: chain.usdcAddress as `0x${string}`,
              abi: erc20BalanceAbi,
              functionName: "decimals",
            }),
          ]);

          rows.push({
            id: chain.id,
            name: chain.name,
            balance: formatUnits(rawBalance, Number(decimals)),
            isTarget: Boolean(chain.isTarget),
            isConfigured: true,
          });
        }

        setBalances(rows);
        setBalanceStatus("idle");
      } catch {
        setBalanceStatus("error");
      }
    };

    loadBalances();
  }, [open, configuredChains, walletClient, isInitialized]);

  const drawerContentStyle = {
    "--initial-transform": "calc(100% + 8px)",
  } as CSSProperties;

  return (
    <Drawer.Root
      direction="right"
      open={open}
      onOpenChange={(nextOpen) => {
        setOpen(nextOpen);
        if (!nextOpen) {
          setAmount("");
        }
      }}
    >
      <Drawer.Trigger asChild>
        <Button className={triggerClassName} disabled={disabled}>
          {triggerLabel}
        </Button>
      </Drawer.Trigger>
      <Drawer.Portal>
        <Drawer.Overlay className="fixed inset-0 z-50 bg-black/40" />
        <Drawer.Content
          className="fixed right-2 top-2 bottom-2 z-50 flex w-[95vw] max-w-[560px] outline-none"
          style={drawerContentStyle}
        >
          <div className="h-full w-full grow overflow-y-auto rounded-[24px] bg-white p-6 shadow-2xl sm:p-8">
            <Drawer.Title className="text-2xl font-semibold text-gray-900">
              Buy Tokens
            </Drawer.Title>
            <Drawer.Description className="leading-6 mt-2 text-sm text-gray-600">
              Purchase {tokenSymbol} from the active sale.
            </Drawer.Description>
            <div className="mt-6">
              <label htmlFor="buy-amount" className="text-sm font-semibold text-gray-900">
                Amount
              </label>
              <Input
                id="buy-amount"
                type="text"
                inputMode="decimal"
                placeholder="1000"
                className="mt-2 h-11 rounded-xl border-2 px-4 text-base"
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
              />
              <p className="mt-2 text-xs text-gray-500">
                Enter the amount of {tokenSymbol} you want to purchase.
              </p>
            </div>
            <Button className="mt-8 h-12 w-full rounded-xl text-base font-semibold">
              Continue to Buy
            </Button>
            <div className="mt-8 rounded-2xl border border-gray-200 bg-gray-50 p-4">
              <div className="text-sm font-semibold text-gray-900">USDC balances</div>
              <div className="mt-3 space-y-2 text-sm text-gray-600">
                {balanceStatus === "loading" && (
                  <div className="text-xs text-gray-500">Loading balances…</div>
                )}
                {balanceStatus === "error" && (
                  <div className="text-xs text-red-600">Failed to load balances.</div>
                )}
                {balanceStatus === "idle" && balances.length === 0 && (
                  <div className="text-xs text-gray-500">Connect a wallet to see balances.</div>
                )}
                {balances.map((row) => (
                  <div key={row.id} className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-gray-900">{row.name}</span>
                      {row.isTarget && (
                        <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] font-semibold text-emerald-700">
                          Target
                        </span>
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      <span className={row.isConfigured ? "text-gray-900" : "text-gray-400"}>
                        {row.balance}
                      </span>
                      {!row.isTarget && (
                        <Button
                          variant="outline"
                          size="sm"
                          className="h-8 rounded-full px-3 text-xs"
                          disabled
                        >
                          Bridge to Base
                        </Button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <p className="mt-3 text-xs text-gray-400">
              Contract: {tokenAddress.slice(0, 8)}…{tokenAddress.slice(-4)}
            </p>
          </div>
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  );
}
