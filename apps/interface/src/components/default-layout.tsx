import { ConnectButton } from '@/components/connect-button'
import { AuthGate } from "./auth-gate";

export default function DefaultLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-svh flex-col bg-white text-neutral-950 dark:bg-neutral-950 dark:text-neutral-50">
      {/* HEADER */}
      <header className="flex h-32 shrink-0 items-center px-4 sm:px-8">
        <div className="flex-1">
          <p>Logo here</p>
        </div>

        <div className="shrink-0">
          <p>Navigation here</p>
        </div>

        <div className="flex flex-1 items-center justify-end gap-2">
          {/* <p/> */}
          <ConnectButton />
        </div>
      </header>


      {/* MAIN */}
      <main className="flex min-h-0 flex-1 flex-col p-8">
        <section className={`flex min-h-0 flex-1 flex-col rounded-2xl p-4 border red`}>
          <AuthGate>
            {children}
          </AuthGate>
        </section>
      </main>
    </div>
  )
}
