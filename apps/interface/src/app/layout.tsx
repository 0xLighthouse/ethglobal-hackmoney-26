import "./globals.css";
import type { ReactNode } from "react";
import { Web3Provider } from "@/providers/web3";
import DefaultLayout from "@/components/default-layout";

export const metadata = {
  title: "Interface",
  description: "Base Next.js app for the interface.",
};

export default function RootLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <Web3Provider>
          <DefaultLayout>{children}</DefaultLayout>
        </Web3Provider>
      </body>
    </html>
  );
}
