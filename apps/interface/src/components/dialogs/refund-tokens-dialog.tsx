"use client";

import { useEffect, useMemo, useState } from "react";
import { formatUnits } from "viem";
import { baseSepolia } from "viem/chains";
import { useWeb3 } from "@/providers/web3";
import { NetworkBase, TokenUSDC } from "@web3icons/react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ERC20RefundableTokenSaleABI } from "@repo/abis";

const explorerBaseUrl =
  baseSepolia.blockExplorers?.default.url ?? "https://sepolia.basescan.org";

type RefundTokensDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  tokenAddress: `0x${string}` | null;
  tokenSymbol: string;
  refundableAmount: bigint;
  currentAddress: `0x${string}` | null;
  onRefunded?: () => void | Promise<void>;
};

type RefundQuote = {
  expectedFundingAmount: bigint;
  fundingTokenSymbol: string;
  fundingTokenDecimals: number;
};

const erc20MetadataAbi = [
  {
    type: "function",
    name: "decimals",
    inputs: [],
    outputs: [{ name: "", internalType: "uint8", type: "uint8" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "symbol",
    inputs: [],
    outputs: [{ name: "", internalType: "string", type: "string" }],
    stateMutability: "view",
  },
] as const;

const formatAmount = (value: bigint, decimals: number) => {
  try {
    const formatted = formatUnits(value, decimals);
    const asNumber = Number(formatted);
    if (Number.isFinite(asNumber)) {
      return new Intl.NumberFormat("en-US", { maximumFractionDigits: 6 }).format(asNumber);
    }
    return formatted;
  } catch {
    return "—";
  }
};

export function RefundTokensDialog({
  open,
  onOpenChange,
  tokenAddress,
  tokenSymbol,
  refundableAmount,
  currentAddress,
  onRefunded,
}: RefundTokensDialogProps) {
  const { walletClient, publicClient, isInitialized } = useWeb3();
  const [quote, setQuote] = useState<RefundQuote | null>(null);
  const [quoteStatus, setQuoteStatus] = useState<"idle" | "loading" | "error">("idle");
  const [quoteError, setQuoteError] = useState<string | null>(null);
  const [submitStatus, setSubmitStatus] = useState<"idle" | "submitting" | "pending" | "success" | "error">("idle");
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null);

  useEffect(() => {
    if (!open || !tokenAddress || refundableAmount <= 0n) {
      return;
    }

    let cancelled = false;

    const loadQuote = async () => {
      setQuoteStatus("loading");
      setQuoteError(null);
      setQuote(null);

      try {
        const [purchasePriceRaw, fundingTokenAddressRaw] = await Promise.all([
          publicClient.readContract({
            address: tokenAddress,
            abi: ERC20RefundableTokenSaleABI,
            functionName: "tokenSalePurchasePrice",
          }),
          publicClient.readContract({
            address: tokenAddress,
            abi: ERC20RefundableTokenSaleABI,
            functionName: "FUNDING_TOKEN",
          }),
        ]);

        const fundingTokenAddress = fundingTokenAddressRaw as `0x${string}`;
        const [fundingTokenDecimalsRaw, fundingTokenSymbolRaw] = await Promise.all([
          publicClient.readContract({
            address: fundingTokenAddress,
            abi: erc20MetadataAbi,
            functionName: "decimals",
          }),
          publicClient.readContract({
            address: fundingTokenAddress,
            abi: erc20MetadataAbi,
            functionName: "symbol",
          }),
        ]);

        if (cancelled) return;

        const purchasePrice = purchasePriceRaw as bigint;
        const fundingTokenDecimals = Number(fundingTokenDecimalsRaw);
        const fundingTokenSymbol = String(fundingTokenSymbolRaw || "Funding token");
        const expectedFundingAmount = refundableAmount * purchasePrice / 10n ** 18n;

        setQuote({
          expectedFundingAmount,
          fundingTokenSymbol,
          fundingTokenDecimals,
        });
        setQuoteStatus("idle");
      } catch (err) {
        if (cancelled) return;
        setQuoteError(err instanceof Error ? err.message : "Failed to quote refund.");
        setQuoteStatus("error");
      }
    };

    loadQuote();

    return () => {
      cancelled = true;
    };
  }, [open, publicClient, refundableAmount, tokenAddress]);

  useEffect(() => {
    if (!open) {
      setQuote(null);
      setQuoteStatus("idle");
      setQuoteError(null);
      setSubmitStatus("idle");
      setSubmitError(null);
      setTxHash(null);
    }
  }, [open]);

  const refundableAmountDisplay = useMemo(
    () => formatAmount(refundableAmount, 18),
    [refundableAmount]
  );

  const expectedRefundDisplay = useMemo(() => {
    if (!quote) return null;
    return `${formatAmount(quote.expectedFundingAmount, quote.fundingTokenDecimals)} ${quote.fundingTokenSymbol}`;
  }, [quote]);

  const handleConfirmRefund = async () => {
    if (!tokenAddress || refundableAmount <= 0n) return;

    if (!walletClient || !isInitialized) {
      setSubmitError("Connect a wallet to refund tokens.");
      setSubmitStatus("error");
      return;
    }

    if (!currentAddress) {
      setSubmitError("No wallet address available.");
      setSubmitStatus("error");
      return;
    }

    setSubmitStatus("submitting");
    setSubmitError(null);
    setTxHash(null);

    try {
      const hash = await walletClient.writeContract({
        address: tokenAddress,
        abi: ERC20RefundableTokenSaleABI,
        functionName: "refund",
        args: [refundableAmount, currentAddress],
        account: currentAddress,
      });

      setTxHash(hash);
      setSubmitStatus("pending");
      await publicClient.waitForTransactionReceipt({ hash });
      setSubmitStatus("success");
      if (onRefunded) {
        await onRefunded();
      }
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Refund failed.");
      setSubmitStatus("error");
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-xl">
        <DialogHeader>
          <DialogTitle className="text-2xl font-semibold text-gray-900">Confirm Refund</DialogTitle>
          <DialogDescription>
            You are refunding {refundableAmountDisplay} {tokenSymbol}.
          </DialogDescription>
        </DialogHeader>

        <div className="rounded-xl border border-emerald-200 bg-emerald-50/60 px-6 py-6 text-center">
          {expectedRefundDisplay ? (
            <div className="space-y-2">
              <p className="text-xs font-semibold tracking-[0.12em] text-emerald-700 uppercase">Expected Refund</p>
              <div className="flex items-center justify-center gap-3">
                <div className="relative">
                  <TokenUSDC variant="branded" size={36} />
                  <span className="absolute -bottom-1 -right-1 rounded-full bg-white p-[1px] shadow-sm">
                    <NetworkBase variant="branded" size={14} />
                  </span>
                </div>
                <p className="text-5xl font-semibold leading-none tracking-tight text-emerald-900">
                  {expectedRefundDisplay}
                </p>
              </div>
            </div>
          ) : quoteStatus === "loading" ? (
            <span className="text-sm text-gray-700">Calculating expected refund amount...</span>
          ) : (
            <span className="text-sm text-gray-700">Unable to calculate expected refund amount.</span>
          )}
        </div>

        {quoteStatus === "error" && quoteError && (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {quoteError}
          </div>
        )}

        {submitStatus === "error" && submitError && (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {submitError}
          </div>
        )}

        {txHash && (
          <div className="space-y-1 text-sm text-gray-700">
            {submitStatus === "pending" && <p>Waiting for confirmation...</p>}
            {submitStatus === "success" && (
              <p className="font-medium text-emerald-700">Refunded.</p>
            )}
            {(submitStatus === "pending" || submitStatus === "success") && (
              <a
                className="inline-block font-semibold text-gray-900 underline underline-offset-2 hover:text-black"
                href={`${explorerBaseUrl}/tx/${txHash}`}
                target="_blank"
                rel="noreferrer"
              >
                View transaction
              </a>
            )}
          </div>
        )}

        <DialogFooter className="pt-1">
          <button
            type="button"
            onClick={() => onOpenChange(false)}
            className="rounded-lg border border-gray-200 px-4 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {submitStatus === "success" ? "Close" : "Cancel"}
          </button>
          {submitStatus !== "success" && (
            <button
              type="button"
              onClick={handleConfirmRefund}
              disabled={
                !tokenAddress
                || refundableAmount <= 0n
                || quoteStatus === "loading"
                || submitStatus === "submitting"
                || submitStatus === "pending"
              }
              className="rounded-lg bg-black px-4 py-2 text-sm font-semibold text-white hover:bg-gray-800 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {submitStatus === "submitting" && "Submitting..."}
              {submitStatus === "pending" && "Confirming..."}
              {(submitStatus === "idle" || submitStatus === "error") && "Confirm Refund"}
            </button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
