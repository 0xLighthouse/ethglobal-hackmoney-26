import { TokenDeploymentsTable } from "@/components/token-deployments-table";

export default function Home() {
  return (
    <div className="flex h-full flex-col">
      <TokenDeploymentsTable />
    </div>
  );
}
