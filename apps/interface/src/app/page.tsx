"use client";

import { useSearchParams } from "next/navigation";
import { TokenDeploymentsTable } from "@/components/token-deployments-table";
import { SalesStatsCards } from "@/components/sales-stats-cards";

export default function Home() {
  const searchParams = useSearchParams();
  const view = searchParams.get("view") === "sales" ? "sales" : "tokens";

  return (
    <div className="flex h-full flex-col">
      {view === "sales" ? <SalesStatsCards /> : <TokenDeploymentsTable />}
    </div>
  );
}
