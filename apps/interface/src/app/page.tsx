import { CreateTokenDialog } from "@/components/dialogs/create-token-dialog";
import { CreateSaleDialog } from "@/components/dialogs/create-sale-dialog";

export default function Home() {
  return (
    <main>
      <div>
        <h1>Interface</h1>
        <p>
          Your base Next.js app is ready. Start building the UI in{" "}
          <code>src/app</code>.
        </p>
        <div className="flex flex-wrap gap-3">
          <CreateTokenDialog />
          <CreateSaleDialog />
        </div>
      </div>
    </main>
  );
}
