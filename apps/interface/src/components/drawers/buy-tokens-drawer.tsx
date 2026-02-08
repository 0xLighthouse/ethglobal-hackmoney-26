"use client";

import { Drawer } from "vaul";
import { useEffect, useMemo, useState, type CSSProperties } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { formatUnits, parseUnits } from "viem";
import { useWeb3 } from "@/providers/web3";
import { ERC20RefundableTokenSaleABI } from "@repo/abis";
import { USDCBridge } from "@/components/usdc-bridge";

type BuyTokensDrawerProps = {
  triggerLabel?: string;
  triggerClassName?: string;
  disabled?: boolean;
  tokenAddress: `0x${string}`;
  tokenSymbol?: string;
  sale?: {
    saleAmount: string;
    purchasePrice: string;
    saleStartBlock: string;
    saleEndBlock: string;
    blockNumber: string;
    txHash: string;
  } | null;
};

const erc20BalanceAbi = [
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", internalType: "address", type: "address" }],
    outputs: [{ name: "", internalType: "uint256", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "decimals",
    inputs: [],
    outputs: [{ name: "", internalType: "uint8", type: "uint8" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "allowance",
    inputs: [
      { name: "owner", internalType: "address", type: "address" },
      { name: "spender", internalType: "address", type: "address" },
    ],
    outputs: [{ name: "", internalType: "uint256", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "approve",
    inputs: [
      { name: "spender", internalType: "address", type: "address" },
      { name: "amount", internalType: "uint256", type: "uint256" },
    ],
    outputs: [{ name: "", internalType: "bool", type: "bool" }],
    stateMutability: "nonpayable",
  },
] as const;

export function BuyTokensDrawer({
  triggerLabel = "Buy Tokens",
  triggerClassName = "h-11 rounded-full px-5 text-sm font-semibold shadow-sm",
  disabled = false,
  tokenAddress,
  tokenSymbol = "Token",
  sale = null,
}: BuyTokensDrawerProps) {
  const { walletClient, publicClient, isInitialized } = useWeb3();
  const [open, setOpen] = useState(false);
  const [amount, setAmount] = useState("");
  const [tokenDecimals, setTokenDecimals] = useState(18);
  const [fundingTokenDecimals, setFundingTokenDecimals] = useState(6);
  const [fundingTokenAddress, setFundingTokenAddress] = useState<`0x${string}` | null>(null);
  const [currentBlock, setCurrentBlock] = useState<bigint | null>(null);
  const [allowance, setAllowance] = useState<bigint>(0n);
  const [approvalStatus, setApprovalStatus] = useState<"idle" | "submitting" | "pending" | "success" | "error">("idle");
  const [approvalError, setApprovalError] = useState<string | null>(null);
  const [status, setStatus] = useState<"idle" | "submitting" | "pending" | "success" | "error">("idle");
  const [error, setError] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null);

  useEffect(() => {
    if (!open) return;
    const loadDecimals = async () => {
      try {
        const latestBlock = await publicClient.getBlockNumber();
        setCurrentBlock(latestBlock);

        const fundingToken = await publicClient.readContract({
          address: tokenAddress,
          abi: ERC20RefundableTokenSaleABI,
          functionName: "FUNDING_TOKEN",
        });
        console.log("[BuyTokens] funding token", fundingToken);
        setFundingTokenAddress(fundingToken as `0x${string}`);

        const [tokenDecimalsValue, fundingDecimalsValue] = await Promise.all([
          publicClient.readContract({
            address: tokenAddress,
            abi: ERC20RefundableTokenSaleABI,
            functionName: "decimals",
          }),
          publicClient.readContract({
            address: fundingToken as `0x${string}`,
            abi: erc20BalanceAbi,
            functionName: "decimals",
          }),
        ]);

        setTokenDecimals(Number(tokenDecimalsValue));
        setFundingTokenDecimals(Number(fundingDecimalsValue));
      } catch {
        setTokenDecimals(18);
        setFundingTokenDecimals(6);
        setFundingTokenAddress(null);
      }
    };

    loadDecimals();
  }, [open, publicClient, tokenAddress]);

  useEffect(() => {
    if (!open || !fundingTokenAddress) return;
    const loadAllowance = async () => {
      try {
        if (!walletClient || !isInitialized) return;
        const [account] = await walletClient.getAddresses();
        if (!account) return;
        const currentAllowance = await publicClient.readContract({
          address: fundingTokenAddress,
          abi: erc20BalanceAbi,
          functionName: "allowance",
          args: [account, tokenAddress],
        });
        setAllowance(currentAllowance);
      } catch {
        // Keep the last known allowance to avoid flicker when reads fail.
      }
    };

    loadAllowance();
  }, [open, fundingTokenAddress, walletClient, isInitialized, publicClient, tokenAddress]);

  const drawerContentStyle = {
    "--initial-transform": "calc(100% + 8px)",
  } as CSSProperties;

  const purchasePriceRaw = useMemo(() => {
    if (!sale?.purchasePrice) return null;
    try {
      return BigInt(sale.purchasePrice);
    } catch {
      return null;
    }
  }, [sale]);

  const formattedPrice = useMemo(() => {
    if (!purchasePriceRaw) return "—";
    try {
      return formatUnits(purchasePriceRaw, fundingTokenDecimals);
    } catch {
      return sale?.purchasePrice ?? "—";
    }
  }, [purchasePriceRaw, fundingTokenDecimals, sale]);

  const tokenAmountFromUsd = useMemo(() => {
    if (!purchasePriceRaw) return null;
    try {
      const usdAmountRaw = parseUnits(amount || "0", fundingTokenDecimals);
      if (usdAmountRaw <= 0n) return null;
      const tokenScale = 10n ** BigInt(tokenDecimals);
      const tokensSmallest = (usdAmountRaw * tokenScale) / purchasePriceRaw;
      if (tokensSmallest <= 0n) return null;
      return formatUnits(tokensSmallest, tokenDecimals);
    } catch {
      return null;
    }
  }, [amount, purchasePriceRaw, fundingTokenDecimals, tokenDecimals]);

  const formattedTokenAmountFromUsd = useMemo(() => {
    if (!tokenAmountFromUsd) return null;
    const value = Number(tokenAmountFromUsd);
    if (!Number.isFinite(value)) return tokenAmountFromUsd;
    if (value > 0 && value < 0.000001) return "<0.000001";
    return new Intl.NumberFormat("en-US", { maximumFractionDigits: 6 }).format(value);
  }, [tokenAmountFromUsd]);

  const requiredFundingAmount = useMemo(() => {
    try {
      if (!purchasePriceRaw) return 0n;
      const usdAmountRaw = parseUnits(amount || "0", fundingTokenDecimals);
      if (usdAmountRaw <= 0n) return 0n;
      return usdAmountRaw;
    } catch {
      return 0n;
    }
  }, [amount, fundingTokenDecimals, purchasePriceRaw, tokenDecimals]);

  const isApproved = useMemo(() => {
    if (!walletClient || !isInitialized) return false;
    if (!requiredFundingAmount) return false;
    return allowance >= requiredFundingAmount;
  }, [allowance, isInitialized, requiredFundingAmount, walletClient]);

  const handleApprove = async () => {
    setApprovalError(null);
    if (!walletClient || !isInitialized) {
      setApprovalError("Connect a wallet to approve USDC.");
      setApprovalStatus("error");
      return;
    }
    if (!fundingTokenAddress) {
      setApprovalError("Funding token unavailable.");
      setApprovalStatus("error");
      return;
    }
    setApprovalStatus("submitting");
    try {
      const [account] = await walletClient.getAddresses();
      if (!account) {
        throw new Error("No wallet address available.");
      }
      const hash = await walletClient.writeContract({
        address: fundingTokenAddress,
        abi: erc20BalanceAbi,
        functionName: "approve",
        args: [tokenAddress, requiredFundingAmount],
        account,
      });
      setApprovalStatus("pending");
      await publicClient.waitForTransactionReceipt({ hash });
      setApprovalStatus("success");
      const currentAllowance = await publicClient.readContract({
        address: fundingTokenAddress,
        abi: erc20BalanceAbi,
        functionName: "allowance",
        args: [account, tokenAddress],
      });

      console.log("[BuyTokens] currentAllowance", currentAllowance);
      setAllowance(currentAllowance);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Approval failed.";
      setApprovalError(message);
      setApprovalStatus("error");
    }
  };

  const handleBuy = async () => {
    setError(null);
    setTxHash(null);

    if (!walletClient || !isInitialized) {
      setError("Connect a wallet to buy tokens.");
      setStatus("error");
      return;
    }

    if (!purchasePriceRaw) {
      setError("Sale price is unavailable.");
      setStatus("error");
      return;
    }


    // ----- START

    console.log("[BuyTokens] amount(input)", amount);
    console.log("[BuyTokens] allowance", allowance);
    console.log("[BuyTokens] unit cost", purchasePriceRaw);
    console.log("[BuyTokens] fundingTokenDecimals", fundingTokenDecimals);

    let usdAmountRaw: bigint;
    let tokenAmountRaw: bigint;
    try {
      usdAmountRaw = parseUnits(amount || "0", fundingTokenDecimals);
      if (usdAmountRaw <= 0n) {
        throw new Error("Enter a USDC amount.");
      }
      const tokenScale = 10n ** BigInt(tokenDecimals);
      tokenAmountRaw = (usdAmountRaw * tokenScale) / purchasePriceRaw;
      if (tokenAmountRaw < tokenScale) {
        throw new Error("USDC amount is too low for 1 token.");
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : "Invalid amount.";
      setError(message);
      setStatus("error");
      return;
    }

    if (!isApproved) {
      setError("Approve USDC before purchasing.");
      setStatus("error");
      return;
    }

    setStatus("submitting");

    try {
      const [account] = await walletClient.getAddresses();
      if (!account) {
        throw new Error("No wallet address available.");
      }

      console.log("[BuyTokens] purchasing", tokenAmountRaw, usdAmountRaw);


      const hash = await walletClient.writeContract({
        address: tokenAddress,
        abi: ERC20RefundableTokenSaleABI,
        functionName: "purchase",
        args: [tokenAmountRaw, usdAmountRaw],
        account,
      });

      setTxHash(hash);
      setStatus("pending");
      await publicClient.waitForTransactionReceipt({ hash });
      setStatus("success");
    } catch (err) {
      const message = err instanceof Error ? err.message : "Purchase failed.";
      setError(message);
      setStatus("error");
    }
  };

  const formattedSaleAmount = useMemo(() => {
    if (!sale?.saleAmount) return "—";
    try {
      return formatUnits(BigInt(sale.saleAmount), 18);
    } catch {
      return sale.saleAmount;
    }
  }, [sale]);

  const saleStatus = useMemo(() => {
    if (!sale || currentBlock === null) return null;
    const start = BigInt(sale.saleStartBlock);
    const end = BigInt(sale.saleEndBlock);
    if (currentBlock < start) return "upcoming";
    if (currentBlock > end) return "closed";
    return "open";
  }, [sale, currentBlock]);

  const saleStatusLabel = useMemo(() => {
    if (!saleStatus) return null;
    if (saleStatus === "open") return "Open";
    if (saleStatus === "closed") return "Closed";
    return "Upcoming";
  }, [saleStatus]);


  return (
    <Drawer.Root
      direction="right"
      open={open}
      onOpenChange={(nextOpen) => {
        setOpen(nextOpen);
        if (!nextOpen) {
          setAmount("");
          setStatus("idle");
          setError(null);
          setTxHash(null);
          setApprovalStatus("idle");
          setApprovalError(null);
        }
      }}
    >
      <Drawer.Trigger asChild>
        <Button className={triggerClassName} disabled={disabled}>
          {triggerLabel}
        </Button>
      </Drawer.Trigger>
      <Drawer.Portal>
        <Drawer.Overlay className="fixed inset-0 z-50 bg-black/40" />
        <Drawer.Content
          className="fixed right-2 top-2 bottom-2 z-50 flex w-[95vw] max-w-[560px] outline-none"
          style={drawerContentStyle}
        >
          <div className="h-full w-full grow overflow-y-auto rounded-[24px] bg-white p-6 shadow-2xl sm:p-8">
            <Drawer.Title className="text-2xl font-semibold text-gray-900">
              Buy Tokens
            </Drawer.Title>
            <Drawer.Description className="leading-6 mt-2 text-sm text-gray-600">
              Purchase {tokenSymbol} from the active sale.
              {formattedPrice !== "—" ? ` ${formattedPrice} USDC per token.` : ""}
            </Drawer.Description>
            <div className="mt-6">
              <label htmlFor="buy-amount" className="text-sm font-semibold text-gray-900">
                Amount (USDC)
              </label>
              <Input
                id="buy-amount"
                type="text"
                inputMode="decimal"
                placeholder="10"
                className="mt-2 h-11 rounded-xl border-2 px-4 text-base"
                value={amount}
                onChange={(event) => {
                  const nextValue = event.target.value.replace(/,/g, "");
                  const sanitized = nextValue.replace(/[^0-9.]/g, "");
                  const [whole, ...rest] = sanitized.split(".");
                  const nextAmount = rest.length > 0 ? `${whole}.${rest.join("")}` : whole;
                  setAmount(nextAmount);
                }}
              />
              <p className="mt-2 text-xs text-gray-500">
                Enter the USDC amount you want to spend.
              </p>
            </div>
            <Button
              className="mt-8 h-12 w-full rounded-xl text-base font-semibold"
              onClick={handleBuy}
              disabled={
                status === "submitting" ||
                status === "pending" ||
                !isApproved
              }
            >
              {status === "pending"
                ? "Buying..."
                : formattedTokenAmountFromUsd
                  ? `Buy ${formattedTokenAmountFromUsd} ${tokenSymbol}`
                  : "Continue to Buy"}
            </Button>
            {formattedTokenAmountFromUsd && (
              <div className="mt-2 text-xs text-gray-500">
                Estimated receive: {formattedTokenAmountFromUsd} {tokenSymbol}
              </div>
            )}
            {!isApproved && requiredFundingAmount > 0n && (
              <Button
                variant="outline"
                className="mt-3 h-11 w-full rounded-xl text-sm font-semibold"
                onClick={handleApprove}
                disabled={approvalStatus === "submitting" || approvalStatus === "pending"}
              >
                {approvalStatus === "pending" ? "Approving..." : "Approve USDC"}
              </Button>
            )}
            {approvalError && (
              <div className="mt-3 text-sm text-red-600">
                {approvalError}
              </div>
            )}
            {error && (
              <div className="mt-3 text-sm text-red-600">
                {error}
              </div>
            )}
            {status === "success" && (
              <div className="mt-3 text-sm text-emerald-600">
                Purchase submitted.
                {txHash ? ` Tx: ${txHash.slice(0, 10)}...` : ""}
              </div>
            )}
            {sale && (
              <div className="mt-6 rounded-2xl border border-gray-200 bg-white p-4">
                <div className="flex items-center justify-between">
                  <div className="text-sm font-semibold text-gray-900">Sale details</div>
                  {saleStatusLabel && (
                    <span
                      className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${
                        saleStatus === "open"
                          ? "bg-emerald-50 text-emerald-700"
                          : saleStatus === "closed"
                            ? "bg-gray-100 text-gray-600"
                            : "bg-amber-50 text-amber-700"
                      }`}
                    >
                      {saleStatusLabel}
                    </span>
                  )}
                </div>
                <div className="mt-3 space-y-2 text-sm text-gray-600">
                  <div className="flex items-center justify-between">
                    <span>Price per token</span>
                    <span className="font-semibold text-gray-900">{formattedPrice} USDC</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span>Tokens for sale</span>
                    <span className="font-semibold text-gray-900">{formattedSaleAmount}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span>Start block</span>
                    <span className="font-semibold text-gray-900">{sale.saleStartBlock}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span>End block</span>
                    <span className="font-semibold text-gray-900">{sale.saleEndBlock}</span>
                  </div>
                  <div className="flex items-center justify-between text-xs text-gray-500">
                    <span>Created in block</span>
                    <span className="font-medium text-gray-700">{sale.blockNumber}</span>
                  </div>
                  <div className="flex items-center justify-between text-xs text-gray-500">
                    <span>Current block</span>
                    <span className="font-medium text-gray-700">
                      {currentBlock ? currentBlock.toString() : "—"}
                    </span>
                  </div>
                </div>
              </div>
            )}
            <USDCBridge />
            <p className="mt-3 text-xs text-gray-400 text-center">
              Native USDC bridge powered by Arc.
            </p>
          </div>
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  );
}
