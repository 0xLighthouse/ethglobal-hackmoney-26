"use client";

import { useEffect, useMemo, useState } from "react";
import { formatUnits } from "viem";
import { useWeb3 } from "@/providers/web3";
import { ERC20RefundableTokenSaleABI } from "@repo/abis";

const DEFAULT_INDEXER_URL = "http://localhost:42069";

type Deployment = {
  id: string;
  token: string;
  name: string;
  symbol: string;
  blockNumber: string;
  sales: {
    items: Sale[];
  };
};

type Sale = {
  token: string;
  blockNumber: string;
};

type SalesStatsRow = {
  deployment: Deployment;
  remainingTokensForSale: bigint;
  fundingTokenSymbol: string;
  fundingTokenDecimals: number;
  raised: bigint;
  refunded: bigint;
  claimed: bigint;
};

const erc20MetadataAbi = [
  {
    type: "function",
    name: "decimals",
    inputs: [],
    outputs: [{ name: "", internalType: "uint8", type: "uint8" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "symbol",
    inputs: [],
    outputs: [{ name: "", internalType: "string", type: "string" }],
    stateMutability: "view",
  },
] as const;

const formatTokenAmount = (value: bigint, symbol: string, decimals = 18) => {
  try {
    const normalized = Number(formatUnits(value, decimals));
    const display = new Intl.NumberFormat("en-US", {
      maximumFractionDigits: 4,
    }).format(normalized);
    return `${display} ${symbol}`;
  } catch {
    return `0 ${symbol}`;
  }
};

const formatDollarAmount = (value: bigint, decimals: number) => {
  try {
    const normalized = Number(formatUnits(value, decimals));
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      maximumFractionDigits: 2,
    }).format(normalized);
  } catch {
    return "$0.00";
  }
};

const fetchDeployments = async (
  indexerUrl: string
): Promise<{ deployments: Deployment[] }> => {
  const query = `
    query Deployments($limit: Int!) {
      tokens(orderBy: "blockNumber", orderDirection: "desc", limit: $limit) {
        items {
          id
          token
          name
          symbol
          blockNumber
        }
      }
      tokenSales(orderBy: "blockNumber", orderDirection: "desc", limit: 200) {
        items {
          token
          blockNumber
        }
      }
    }
  `;

  const response = await fetch(`${indexerUrl}/graphql`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ query, variables: { limit: 50 } })
  });

  if (!response.ok) {
    throw new Error(`Indexer request failed (${response.status}).`);
  }

  const payload = await response.json();
  if (payload.errors?.length) {
    throw new Error(payload.errors[0]?.message ?? "Indexer query failed.");
  }

  const deployments = payload.data?.tokens?.items ?? [];
  const sales = payload.data?.tokenSales?.items ?? [];

  const saleByToken = new Map<string, Sale>();
  for (const sale of sales) {
    const token = String(sale.token).toLowerCase();
    if (!saleByToken.has(token)) {
      saleByToken.set(token, sale);
    }
  }

  const withSales = deployments.map((deployment: Deployment) => {
    const sale = saleByToken.get(deployment.token.toLowerCase());
    return {
      ...deployment,
      sales: {
        items: sale ? [sale] : [],
      },
    };
  });

  return { deployments: withSales };
};

const loadStatsForDeployment = async (
  deployment: Deployment,
  publicClient: ReturnType<typeof useWeb3>["publicClient"]
): Promise<SalesStatsRow> => {
  const tokenAddress = deployment.token as `0x${string}`;
  const fromBlock = BigInt(deployment.blockNumber);

  const [remainingTokensForSale, fundingTokensHeld, totalFundsClaimed, fundingTokenAddress] = await Promise.all([
    publicClient.readContract({
      address: tokenAddress,
      abi: ERC20RefundableTokenSaleABI,
      functionName: "remainingTokensForSale",
    }),
    publicClient.readContract({
      address: tokenAddress,
      abi: ERC20RefundableTokenSaleABI,
      functionName: "fundingTokensHeld",
    }),
    publicClient.readContract({
      address: tokenAddress,
      abi: ERC20RefundableTokenSaleABI,
      functionName: "totalFundsClaimed",
    }),
    publicClient.readContract({
      address: tokenAddress,
      abi: ERC20RefundableTokenSaleABI,
      functionName: "FUNDING_TOKEN",
    }),
  ]);

  const [fundingTokenDecimalsRaw, fundingTokenSymbolRaw, refundedEvents] = await Promise.all([
    publicClient.readContract({
      address: fundingTokenAddress as `0x${string}`,
      abi: erc20MetadataAbi,
      functionName: "decimals",
    }),
    publicClient.readContract({
      address: fundingTokenAddress as `0x${string}`,
      abi: erc20MetadataAbi,
      functionName: "symbol",
    }),
    publicClient.getContractEvents({
      address: tokenAddress,
      abi: ERC20RefundableTokenSaleABI,
      eventName: "Refunded",
      fromBlock,
    }),
  ]);

  const refunded = refundedEvents.reduce((sum, event) => {
    const amount = event.args.fundingTokenAmount;
    return sum + (typeof amount === "bigint" ? amount : 0n);
  }, 0n);

  const held = fundingTokensHeld as bigint;
  const claimed = totalFundsClaimed as bigint;

  return {
    deployment,
    remainingTokensForSale: remainingTokensForSale as bigint,
    fundingTokenSymbol: String(fundingTokenSymbolRaw || "USDC"),
    fundingTokenDecimals: Number(fundingTokenDecimalsRaw),
    refunded,
    claimed,
    raised: held + claimed + refunded,
  };
};

export function SalesStatsCards() {
  const indexerUrl = useMemo(
    () => process.env.NEXT_PUBLIC_INDEXER_URL ?? DEFAULT_INDEXER_URL,
    []
  );
  const { publicClient } = useWeb3();
  const [rows, setRows] = useState<SalesStatsRow[]>([]);
  const [status, setStatus] = useState<"idle" | "loading" | "error">("idle");
  const [error, setError] = useState<string | null>(null);

  const load = async () => {
    setStatus("loading");
    setError(null);

    try {
      const { deployments } = await fetchDeployments(indexerUrl);
      const withSales = deployments.filter((deployment) => deployment.sales.items.length > 0);

      const result = await Promise.all(withSales.map((deployment) => loadStatsForDeployment(deployment, publicClient)));
      setRows(result);
      setStatus("idle");
    } catch (err) {
      setStatus("error");
      setError(err instanceof Error ? err.message : "Failed to load sales stats.");
    }
  };

  useEffect(() => {
    load();
    const timer = setInterval(load, 30_000);
    return () => clearInterval(timer);
  }, []);

  return (
    <section className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <h2 className="text-2xl font-semibold text-gray-900">Sales Overview</h2>
        <button
          type="button"
          onClick={load}
          className="rounded-full border border-gray-200 px-4 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50"
        >
          Refresh
        </button>
      </div>

      {status === "error" && error && (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {rows.length === 0 && status !== "error" && (
        <div className="rounded-xl border border-gray-200 bg-gray-50 px-4 py-8 text-sm text-gray-600">
          {status === "loading" ? "Loading sales stats..." : "No sales available yet."}
        </div>
      )}

      <div className="grid gap-4 md:grid-cols-2">
        {rows.map((row) => (
          <article key={row.deployment.id} className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <div className="mb-4">
              <h3 className="text-lg font-semibold text-gray-900">{row.deployment.name}</h3>
              <p className="text-sm font-mono text-gray-500">{row.deployment.symbol}</p>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-xl border border-gray-100 bg-gray-50 px-3 py-3">
                <p className="text-[11px] uppercase tracking-wide text-gray-500">Remaining tokens for sale</p>
                <p className="mt-1 text-lg font-semibold text-gray-900">
                  {formatTokenAmount(row.remainingTokensForSale, row.deployment.symbol)}
                </p>
              </div>

              <div className="rounded-xl border border-gray-100 bg-gray-50 px-3 py-3">
                <p className="text-[11px] uppercase tracking-wide text-gray-500">$$ raised</p>
                <p className="mt-1 text-lg font-semibold text-gray-900">
                  {formatDollarAmount(row.raised, row.fundingTokenDecimals)}
                </p>
              </div>

              <div className="rounded-xl border border-gray-100 bg-gray-50 px-3 py-3">
                <p className="text-[11px] uppercase tracking-wide text-gray-500">$$ refunded</p>
                <p className="mt-1 text-lg font-semibold text-gray-900">
                  {formatDollarAmount(row.refunded, row.fundingTokenDecimals)}
                </p>
              </div>

              <div className="rounded-xl border border-gray-100 bg-gray-50 px-3 py-3">
                <p className="text-[11px] uppercase tracking-wide text-gray-500">$$ claimed</p>
                <p className="mt-1 text-lg font-semibold text-gray-900">
                  {formatDollarAmount(row.claimed, row.fundingTokenDecimals)}
                </p>
              </div>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
