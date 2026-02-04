"use client";

import { useEffect, useMemo, useState } from "react";
import { useWeb3 } from "@/providers/web3";
import { CreateSaleDialog } from "@/components/dialogs/create-sale-dialog";
import { CreateTokenDialog } from "@/components/dialogs/create-token-dialog";

const DEFAULT_INDEXER_URL = "http://localhost:42069";

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
};

const shortAddress = (value: string) => {
  if (!value) return "";
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
};

const fetchDeployments = async (indexerUrl: string): Promise<Deployment[]> => {
  const query = `
    query Deployments($limit: Int!) {
      refundableTokenDeployments(orderBy: "blockNumber", orderDirection: "desc", limit: $limit) {
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

  const data = payload.data?.refundableTokenDeployments;
  if (Array.isArray(data)) {
    return data as Deployment[];
  }

  return (data?.items ?? []) as Deployment[];
};

export function TokenDeploymentsTable() {
  const indexerUrl = useMemo(
    () => process.env.NEXT_PUBLIC_INDEXER_URL ?? DEFAULT_INDEXER_URL,
    []
  );
  const { walletClient, isInitialized } = useWeb3();
  const [currentAddress, setCurrentAddress] = useState<string | null>(null);
  const [deployments, setDeployments] = useState<Deployment[]>([]);
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
      const items = await fetchDeployments(indexerUrl);
      setDeployments(items);
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
    <section className="mt-6">
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

      <div className="mt-4 overflow-hidden rounded-3xl border border-gray-200 bg-white">
        <table className="w-full text-left text-sm md:text-base">
          <thead className="bg-gray-50 text-[11px] uppercase tracking-wide text-gray-500">
            <tr>
              <th className="px-5 py-4">Token</th>
              <th className="px-5 py-4">Network</th>
              <th className="px-5 py-4">Max Supply</th>
              <th className="px-5 py-4">Deployer</th>
              <th className="px-5 py-4">Beneficiary</th>
              <th className="px-5 py-4">Block</th>
              <th className="px-5 py-4">Tx</th>
              <th className="px-5 py-4">Status</th>
              <th className="px-5 py-4">Actions</th>
            </tr>
          </thead>
          <tbody>
            {deployments.length === 0 && status !== "error" && (
              <tr>
                <td className="px-5 py-8 text-gray-500" colSpan={9}>
                  {status === "loading" ? "Loading deployments..." : "No deployments yet."}
                </td>
              </tr>
            )}
            {deployments.map((deployment) => {
              const isDeployer =
                currentAddress?.toLowerCase() === deployment.deployer.toLowerCase();

              return (
                <tr key={deployment.id} className="border-t border-gray-100">
                  <td className="px-5 py-5">
                    <div className="font-medium text-gray-900">{deployment.name}</div>
                    <div className="text-xs font-mono text-gray-500">{deployment.symbol}</div>
                  </td>
                  <td className="px-5 py-5 text-gray-700">Base</td>
                  <td className="px-5 py-5 text-gray-700">{deployment.maxSupply}</td>
                  <td className="px-5 py-5 text-gray-700">
                    <span className="font-mono">{shortAddress(deployment.deployer)}</span>
                  </td>
                  <td className="px-5 py-5 text-gray-700">
                    <span className="font-mono">{shortAddress(deployment.beneficiary)}</span>
                  </td>
                  <td className="px-5 py-5 text-gray-700">{deployment.blockNumber}</td>
                  <td className="px-5 py-5 text-gray-700">
                    <span className="font-mono">{shortAddress(deployment.txHash)}</span>
                  </td>
                  <td className="px-5 py-5 text-gray-500">—</td>
                  <td className="px-5 py-5 text-gray-700">
                    {isDeployer ? (
                      <CreateSaleDialog
                        triggerLabel="Create Sale"
                        triggerClassName="h-10 rounded-full px-5 text-xs font-semibold"
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
