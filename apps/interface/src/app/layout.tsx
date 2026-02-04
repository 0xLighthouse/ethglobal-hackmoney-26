import "./globals.css";
import type { ReactNode } from "react";

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
      <body>{children}</body>
    </html>
  );
}
