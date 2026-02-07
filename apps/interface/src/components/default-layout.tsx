"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { ConnectButton } from "@/components/connect-button";
import { AuthGate } from "./auth-gate";

export default function DefaultLayout({ children }: { children: React.ReactNode }) {
  const searchParams = useSearchParams();
  const view = searchParams.get("view") === "sales" ? "sales" : "tokens";

  return (
    <div className="flex min-h-svh flex-col bg-gray-50 text-neutral-950 dark:bg-neutral-950 dark:text-neutral-50">
      <header className="flex h-24 shrink-0 items-center border-b border-neutral-200/70 px-4 sm:px-8">
        <div className="flex-1">
          <p>Logo here</p>
        </div>

        <nav className="shrink-0" aria-label="Primary">
          <div className="flex items-center gap-10 text-2xl font-semibold tracking-tight">
            <Link
              href="/?view=tokens"
              className={view === "tokens"
                ? "text-neutral-950 dark:text-white"
                : "font-normal text-neutral-400 transition-colors hover:text-neutral-900 dark:text-neutral-500 dark:hover:text-white"}
              aria-current={view === "tokens" ? "page" : undefined}
            >
              Tokens
            </Link>
            <Link
              href="/?view=sales"
              className={view === "sales"
                ? "text-neutral-950 dark:text-white"
                : "font-normal text-neutral-400 transition-colors hover:text-neutral-900 dark:text-neutral-500 dark:hover:text-white"}
              aria-current={view === "sales" ? "page" : undefined}
            >
              Sales
            </Link>
          </div>
        </nav>

        <div className="flex flex-1 items-center justify-end gap-2">
          <ConnectButton />
        </div>
      </header>

      <main className="flex min-h-0 flex-1 flex-col px-4 py-6 sm:px-6">
        <section className="flex min-h-0 flex-1 flex-col rounded-[32px] border border-neutral-200/70 bg-white p-6 shadow-sm">
          <AuthGate>
            {children}
          </AuthGate>
        </section>
      </main>
    </div>
  );
}
