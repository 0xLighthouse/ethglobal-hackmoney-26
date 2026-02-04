import { CreateTokenDialog } from "@/components/dialogs/create-token-dialog";
import { TokenDeploymentsTable } from "@/components/token-deployments-table";

export default function Home() {
  return (
    <main className="min-h-screen bg-gray-50 px-0 py-8">
      <div className="mx-auto w-full max-w-none">
        <TokenDeploymentsTable />
      </div>
    </main>
  );
}
