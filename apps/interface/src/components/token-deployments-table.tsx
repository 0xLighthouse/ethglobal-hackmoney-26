"use client";

import { useEffect, useMemo, useState } from "react";
import { baseSepolia } from "viem/chains";
import { useWeb3 } from "@/providers/web3";
import { CreateSaleDrawer } from "@/components/drawers/create-sale-drawer";
import { BuyTokensDrawer } from "@/components/drawers/buy-tokens-drawer";
import { CreateTokenDialog } from "@/components/dialogs/create-token-dialog";
import { formatUnits } from "viem";
import { resolveAvatar } from "@/lib/utils";
import { NetworkBase } from "@web3icons/react";

const DEFAULT_INDEXER_URL = "http://localhost:42069";
const explorerBaseUrl =
  baseSepolia.blockExplorers?.default.url ?? "https://sepolia.basescan.org";

type Deployment = {
  id: string;
  token: string;
  deployer: string;
  beneficiary: string;
  name: string;
  symbol: string;
  maxSupply: string;
  blockNumber: string;
  txHash: string;
  sales: {
    items: Sale[];
  };
};

type Sale = {
  token: string;
  saleAmount: string;
  purchasePrice: string;
  saleStartBlock: string;
  saleEndBlock: string;
  blockNumber: string;
  txHash: string;
};

type SaleStatus = "active" | "ended" | "none";

const shortAddress = (value: string) => {
  if (!value) return "";
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
};

const formatMaxSupply = (value: string) => {
  if (!value) return "—";
  try {
    return new Intl.NumberFormat("en-US").format(Number(formatUnits(BigInt(value), 18)));
  } catch {
    return "—";
  }
};

const getSaleStatus = (
  deployment: Deployment,
  latestBlockNumber: bigint | null
): SaleStatus => {
  const sale = deployment.sales.items[0];
  if (!sale || latestBlockNumber === null) return "none";
  const saleEndBlock = BigInt(sale.saleEndBlock);
  return latestBlockNumber <= saleEndBlock ? "active" : "ended";
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
          deployer
          beneficiary
          name
          symbol
          maxSupply
          blockNumber
          txHash
        }
      }
      tokenSales(orderBy: "blockNumber", orderDirection: "desc", limit: 200) {
        items {
          token
          saleAmount
          purchasePrice
          saleStartBlock
          saleEndBlock
          blockNumber
          txHash
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

export function TokenDeploymentsTable() {
  const indexerUrl = useMemo(
    () => process.env.NEXT_PUBLIC_INDEXER_URL ?? DEFAULT_INDEXER_URL,
    []
  );
  const { walletClient, publicClient, isInitialized } = useWeb3();
  const [currentAddress, setCurrentAddress] = useState<string | null>(null);
  const [deployments, setDeployments] = useState<Deployment[]>([]);
  const [latestBlockNumber, setLatestBlockNumber] = useState<bigint | null>(null);
  const [status, setStatus] = useState<"idle" | "loading" | "error">("idle");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadAddress = async () => {
      if (!walletClient || !isInitialized) {
        setCurrentAddress(null);
        return;
      }
      const [address] = await walletClient.getAddresses();
      setCurrentAddress(address ?? null);
    };

    loadAddress();
  }, [walletClient, isInitialized]);

  const load = async () => {
    setStatus("loading");
    setError(null);
    try {
      const result = await fetchDeployments(indexerUrl);
      setDeployments(result.deployments);
      const blockNumber = await publicClient.getBlockNumber();
      setLatestBlockNumber(blockNumber);
      setStatus("idle");
    } catch (err) {
      setStatus("error");
      setError(err instanceof Error ? err.message : "Failed to load deployments.");
    }
  };

  useEffect(() => {
    load();
    const timer = setInterval(() => {
      load();
    }, 30_000);

    return () => clearInterval(timer);
  }, []);

  return (
    <section>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-2xl font-semibold text-gray-900">Recently Created</h2>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={load}
            className="rounded-full border border-gray-200 px-4 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50"
          >
            Refresh
          </button>
          <CreateTokenDialog />
        </div>
      </div>

      {status === "error" && error && (
        <div className="mt-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="mt-4 overflow-hidden border-gray-200 bg-white">
        <table className="w-full text-left text-sm md:text-base">
          <thead className="bg-gray-50 text-[11px] uppercase tracking-wide text-gray-500">
            <tr>
              <th className="px-5 py-4">Token</th>
              <th className="px-5 py-4">Max Supply</th>
              <th className="px-5 py-4">Beneficiary</th>
              <th className="px-5 py-4">Status</th>
              <th className="px-5 py-4">Actions</th>
            </tr>
          </thead>
          <tbody>
            {deployments.length === 0 && status !== "error" && (
              <tr>
                <td className="px-5 py-8 text-gray-500" colSpan={5}>
                  {status === "loading" ? "Loading deployments..." : "No deployments yet."}
                </td>
              </tr>
            )}
            {deployments.map((deployment) => {
              const isDeployer =
                currentAddress?.toLowerCase() === deployment.deployer.toLowerCase();
              const saleStatus = getSaleStatus(deployment, latestBlockNumber);

              return (
                <tr key={deployment.id} className="border-t border-gray-100">
                  <td className="px-5 py-5">
                    <div className="flex items-center gap-3">
                      <div className="relative h-9 w-9">
                        <img
                          src={resolveAvatar(deployment.token, 36)}
                          alt={`${deployment.name} avatar`}
                          className="h-9 w-9 rounded-full border border-gray-200 bg-gray-100"
                          onError={(event) => {
                            event.currentTarget.style.display = "none";
                          }}
                        />
                        <span className="absolute -bottom-1 -right-1 inline-flex h-4 w-4 items-center justify-center rounded-full bg-white shadow-sm ring-1 ring-gray-200">
                          <NetworkBase variant="branded" size={12} />
                        </span>
                      </div>
                      <div>
                        <div className="font-medium text-gray-900">{deployment.name}{' '}<span className="text-xs font-mono text-gray-500">{deployment.symbol}</span></div>
                        <a
                          className="mt-1 inline-flex text-xs font-mono text-gray-400 hover:text-gray-600"
                          href={`${explorerBaseUrl}/address/${deployment.token}`}
                          target="_blank"
                          rel="noreferrer"
                          title={deployment.token}
                        >
                          {shortAddress(deployment.token)}
                        </a>
                      </div>
                    </div>
                  </td>
                  <td className="px-5 py-5 text-gray-700">
                    {formatMaxSupply(deployment.maxSupply)} {deployment.symbol}
                  </td>
                  <td className="px-5 py-5 text-gray-700">
                    <a
                      className="font-mono text-gray-700 hover:text-gray-900"
                      href={`${explorerBaseUrl}/address/${deployment.beneficiary}`}
                      target="_blank"
                      rel="noreferrer"
                      title={deployment.beneficiary}
                    >
                      {shortAddress(deployment.beneficiary)}
                    </a>
                  </td>
                  <td className="px-5 py-5 text-gray-500">
                    {saleStatus === "active" && (
                      <span className="inline-flex items-center gap-1 rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-700">
                        Active
                      </span>
                    )}
                    {saleStatus === "ended" && (
                      <span className="inline-flex items-center gap-1 rounded-full bg-gray-100 px-3 py-1 text-xs font-semibold text-gray-600">
                        Ended
                      </span>
                    )}
                    {saleStatus === "none" && "—"}
                  </td>
                  <td className="px-5 py-5 text-gray-700">
                    {saleStatus === "active" ? (
                      <BuyTokensDrawer
                        triggerLabel="Buy Tokens"
                        triggerClassName="h-10 rounded-full px-5 text-xs font-semibold"
                        tokenAddress={deployment.token as `0x${string}`}
                        tokenSymbol={deployment.symbol}
                        sale={deployment.sales.items[0] ?? null}
                      />
                    ) : isDeployer ? (
                      <CreateSaleDrawer
                        triggerLabel="Create Sale"
                        triggerClassName="h-10 rounded-full px-5 text-xs font-semibold"
                        tokenAddress={deployment.token as `0x${string}`}
                        tokenSymbol={deployment.symbol}
                      />
                    ) : (
                      <span className="text-xs text-gray-400">Deployer only</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
}
