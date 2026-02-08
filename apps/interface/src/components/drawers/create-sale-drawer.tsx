"use client";

import { Drawer } from "vaul";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Input } from "@/components/ui/input";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { format } from "date-fns";
import { CalendarIcon, ChevronDownIcon } from "lucide-react";
import { useEffect, useMemo, useState, type CSSProperties } from "react";
import { Controller, useForm, useWatch } from "react-hook-form";
import { formatUnits, parseUnits } from "viem";
import { useWeb3 } from "@/providers/web3";
import { AVERAGE_BLOCK_TIME_SECONDS_BY_CHAIN_ID } from "@/config/block-times";
import { createSaleFormDefaults, useCreateSaleStore } from "@/stores/create-sale";
import { ERC20RefundableTokenSaleABI } from "@repo/abis";

type CreateSaleDrawerProps = {
  triggerLabel?: string;
  triggerClassName?: string;
  disabled?: boolean;
  tokenAddress: `0x${string}`;
  tokenSymbol?: string;
};

type CreateSaleFormValues = {
  amount: string;
  price: string;
  startDate: string | null;
  startTime: string;
  endDate: string | null;
  endTime: string;
  refundableBps: string;
  decayDelay: string;
  decayDuration: string;
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

export function CreateSaleDrawer({
  triggerLabel = "Create Sale",
  triggerClassName = "h-11 rounded-full px-5 text-sm font-semibold shadow-sm",
  disabled = false,
  tokenAddress,
  tokenSymbol = "Token",
}: CreateSaleDrawerProps) {
  const { publicClient, walletClient, isInitialized } = useWeb3();
  const { form, setForm, reset: resetStore } = useCreateSaleStore();
  const [open, setOpen] = useState(false);
  const [startPickerOpen, setStartPickerOpen] = useState(false);
  const [endPickerOpen, setEndPickerOpen] = useState(false);
  const [startBlock, setStartBlock] = useState<string>("");
  const [endBlock, setEndBlock] = useState<string>("");
  const [tokenDecimals, setTokenDecimals] = useState(18);
  const [fundingTokenAddress, setFundingTokenAddress] = useState<`0x${string}` | null>(null);
  const [fundingTokenDecimals, setFundingTokenDecimals] = useState(6);
  const [fundingTokenSymbol, setFundingTokenSymbol] = useState("Funding token");
  const [contractBalance, setContractBalance] = useState<bigint | null>(null);
  const [balanceStatus, setBalanceStatus] = useState<"idle" | "loading" | "error">("idle");
  const [latestBlockNumber, setLatestBlockNumber] = useState<bigint | null>(null);
  const [latestBlockTimestamp, setLatestBlockTimestamp] = useState<bigint | null>(null);
  const [status, setStatus] = useState<"idle" | "submitting" | "pending" | "success" | "error">("idle");
  const [error, setError] = useState<string | null>(null);
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null);

  const {
    control,
    register,
    handleSubmit,
    setValue,
    reset,
  } = useForm<CreateSaleFormValues>({
    defaultValues: form,
    mode: "onChange",
  });

  const watched = useWatch({ control });
  const amount = watched?.amount ?? "";
  const price = watched?.price ?? "";
  const startDateValue = watched?.startDate ? new Date(watched.startDate) : undefined;
  const startTime = watched?.startTime ?? "00:00";
  const endDateValue = watched?.endDate ? new Date(watched.endDate) : undefined;
  const endTime = watched?.endTime ?? "00:00";
  const refundableBps = watched?.refundableBps ?? "80.00";
  const decayDelay = watched?.decayDelay ?? "100";
  const decayDuration = watched?.decayDuration ?? "200";

  const resetFormState = () => {
    reset(createSaleFormDefaults);
    resetStore();
    setStartBlock("");
    setEndBlock("");
    setBalanceStatus("idle");
    setStatus("idle");
    setError(null);
    setTxHash(null);
  };

  const averageBlockTimeSeconds = useMemo(() => {
    return (
      AVERAGE_BLOCK_TIME_SECONDS_BY_CHAIN_ID[publicClient.chain.id] ??
      AVERAGE_BLOCK_TIME_SECONDS_BY_CHAIN_ID.default
    );
  }, [publicClient.chain.id]);

  const formattedContractBalance = useMemo(() => {
    if (contractBalance === null) return "—";
    try {
      return new Intl.NumberFormat("en-US", { maximumFractionDigits: 6 }).format(
        Number(formatUnits(contractBalance, tokenDecimals))
      );
    } catch {
      return formatUnits(contractBalance, tokenDecimals);
    }
  }, [contractBalance, tokenDecimals]);

  const formattedAmount = useMemo(() => {
    if (!amount) return "";
    const [whole, fraction] = amount.split(".");
    const formattedWhole = new Intl.NumberFormat("en-US").format(Number(whole || "0"));
    if (fraction === undefined) return formattedWhole;
    return `${formattedWhole}.${fraction}`;
  }, [amount]);

  useEffect(() => {
    if (!watched) return;
    setForm({
      ...createSaleFormDefaults,
      ...watched,
      startDate: watched.startDate ?? null,
      endDate: watched.endDate ?? null,
    } as CreateSaleFormValues);
  }, [watched, setForm]);

  const estimateBlockNumber = (value: Date | null) => {
    if (!value || latestBlockNumber === null || latestBlockTimestamp === null) return "";
    const deltaSeconds = Math.round(value.getTime() / 1000) - Number(latestBlockTimestamp);
    const blocksDelta = Math.round(deltaSeconds / averageBlockTimeSeconds);
    const estimate = latestBlockNumber + BigInt(blocksDelta);
    if (estimate < 0n) return "0";
    return estimate.toString();
  };

  const combineDateTime = (date: Date | undefined, time: string) => {
    if (!date) return null;
    const [hours, minutes] = time.split(":").map((value) => Number(value));
    const next = new Date(date);
    if (Number.isFinite(hours)) next.setHours(hours);
    if (Number.isFinite(minutes)) next.setMinutes(minutes);
    next.setSeconds(0, 0);
    return next;
  };

  const expectedRaise = useMemo(() => {
    const amountValue = Number(amount);
    const priceValue = Number(price);
    if (!Number.isFinite(amountValue) || !Number.isFinite(priceValue)) return null;
    if (amountValue <= 0 || priceValue <= 0) return null;
    const value = amountValue * priceValue;
    return new Intl.NumberFormat("en-US", { maximumFractionDigits: 6 }).format(value);
  }, [amount, price]);

  const startDateTime = useMemo(() => combineDateTime(startDateValue, startTime), [startDateValue, startTime]);
  const endDateTime = useMemo(() => combineDateTime(endDateValue, endTime), [endDateValue, endTime]);

  const formattedStartDateTime = useMemo(() => {
    if (!startDateTime) return "—";
    return format(startDateTime, "MMM d, yyyy h:mm a");
  }, [startDateTime]);

  const formattedEndDateTime = useMemo(() => {
    if (!endDateTime) return "—";
    return format(endDateTime, "MMM d, yyyy h:mm a");
  }, [endDateTime]);

  useEffect(() => {
    if (!open) return;

    const loadBalance = async () => {
      setBalanceStatus("loading");
      try {
        const [decimals, balance, fundingToken] = await Promise.all([
          publicClient.readContract({
            address: tokenAddress,
            abi: ERC20RefundableTokenSaleABI,
            functionName: "decimals",
          }),
          publicClient.readContract({
            address: tokenAddress,
            abi: ERC20RefundableTokenSaleABI,
            functionName: "balanceOf",
            args: [tokenAddress],
          }),
          publicClient.readContract({
            address: tokenAddress,
            abi: ERC20RefundableTokenSaleABI,
            functionName: "FUNDING_TOKEN",
          }),
        ]);


        setTokenDecimals(Number(decimals));
        setContractBalance(balance);
        setFundingTokenAddress(fundingToken as `0x${string}`);
        try {
          const [fundingDecimals, fundingSymbol] = await Promise.all([
            publicClient.readContract({
              address: fundingToken as `0x${string}`,
              abi: erc20MetadataAbi,
              functionName: "decimals",
            }),
            publicClient.readContract({
              address: fundingToken as `0x${string}`,
              abi: erc20MetadataAbi,
              functionName: "symbol",
            }),
          ]);
          setFundingTokenDecimals(Number(fundingDecimals));
          setFundingTokenSymbol(String(fundingSymbol));
        } catch {
          setFundingTokenDecimals(6);
          setFundingTokenSymbol("Funding token");
        }
        setBalanceStatus("idle");
      } catch {
        setBalanceStatus("error");
      }
    };

    const loadBlock = async () => {
      const block = await publicClient.getBlock();
      setLatestBlockNumber(block.number);
      setLatestBlockTimestamp(block.timestamp);
    };

    loadBalance();
    loadBlock();
  }, [open, publicClient, tokenAddress]);

  useEffect(() => {
    setStartBlock(estimateBlockNumber(startDateTime));
  }, [startDateTime, latestBlockNumber, latestBlockTimestamp, averageBlockTimeSeconds]);

  useEffect(() => {
    setEndBlock(estimateBlockNumber(endDateTime));
  }, [endDateTime, latestBlockNumber, latestBlockTimestamp, averageBlockTimeSeconds]);

  const parsePositiveBigInt = (value: string, label: string) => {
    if (!value || value.trim().length === 0) {
      throw new Error(`${label} is required.`);
    }
    const parsed = BigInt(Math.max(0, Math.floor(Number(value))));
    if (parsed < 0n) {
      throw new Error(`${label} must be positive.`);
    }
    return parsed;
  };

  const buildSaleParams = (values: CreateSaleFormValues) => {
    if (!values.amount || !values.price) {
      throw new Error("Enter a sale amount and price.");
    }
    if (!startBlock || !endBlock) {
      throw new Error("Select start and end time.");
    }

    const saleAmount = parseUnits(values.amount, tokenDecimals);
    const purchasePrice = parseUnits(values.price, fundingTokenDecimals);
    const saleStartBlock = BigInt(startBlock);
    const saleEndBlock = BigInt(endBlock);

    const bpsValue = Math.round(Number(values.refundableBps) * 100);
    if (!Number.isFinite(bpsValue)) {
      throw new Error("Invalid refundable percentage.");
    }
    const refundableBpsAtStart = BigInt(bpsValue);

    const refundableDelayBlocks = parsePositiveBigInt(values.decayDelay, "Decay delay");
    const refundableDurationBlocks = parsePositiveBigInt(values.decayDuration, "Decay duration");

    if (saleAmount <= 0n || purchasePrice <= 0n) {
      throw new Error("Sale amount and price must be greater than zero.");
    }
    if (saleStartBlock > saleEndBlock) {
      throw new Error("Start time must be before end time.");
    }
    if (refundableBpsAtStart < 0n || refundableBpsAtStart > 10_000n) {
      throw new Error("Refundable % must be between 0 and 100.");
    }

    const refundableDecayStartBlock = saleStartBlock + refundableDelayBlocks;
    const refundableDecayEndBlock = refundableDecayStartBlock + refundableDurationBlocks;

    return {
      saleAmount,
      purchasePrice,
      saleStartBlock,
      saleEndBlock,
      refundableDecayStartBlock,
      refundableDecayEndBlock,
      refundableBpsAtStart,
    };
  };

  const handleCreateSale = handleSubmit(async (values) => {
    setError(null);
    setTxHash(null);

    if (!walletClient || !isInitialized) {
      setError("Connect a wallet to create a sale.");
      setStatus("error");
      return;
    }

    let params: ReturnType<typeof buildSaleParams>;
    try {
      params = buildSaleParams(values);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Invalid inputs.";
      setError(message);
      setStatus("error");
      return;
    }

    setStatus("submitting");

    try {
      const [account] = await walletClient.getAddresses();
      if (!account) {
        throw new Error("No wallet address available.");
      }

      const hash = await walletClient.writeContract({
        address: tokenAddress,
        abi: ERC20RefundableTokenSaleABI,
        functionName: "createSale",
        args: [
          {
            saleAmount: params.saleAmount,
            purchasePrice: params.purchasePrice,
            saleStartBlock: params.saleStartBlock,
            saleEndBlock: params.saleEndBlock,
            refundableDecayStartBlock: params.refundableDecayStartBlock,
            refundableDecayEndBlock: params.refundableDecayEndBlock,
            refundableBpsAtStart: params.refundableBpsAtStart,
          },
        ],
        account,
      });

      setTxHash(hash);
      setStatus("pending");
      await publicClient.waitForTransactionReceipt({ hash });
      setStatus("success");
    } catch (err) {
      const message = err instanceof Error ? err.message : "Create sale failed.";
      setError(message);
      setStatus("error");
    }
  });

  const drawerContentStyle = {
    "--initial-transform": "calc(100% + 8px)",
  } as CSSProperties;

  return (
    <Drawer.Root
      direction="right"
      open={open}
      onOpenChange={(nextOpen) => {
        setOpen(nextOpen);
        if (!nextOpen && status === "success") {
          resetFormState();
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
          className="fixed right-2 top-2 bottom-2 z-50 flex w-[95vw] max-w-[1100px] outline-none"
          style={drawerContentStyle}
        >
          <div className="h-full w-full grow overflow-y-auto rounded-[24px] bg-white p-6 shadow-2xl sm:p-12">
            <Drawer.Title className="text-2xl font-semibold text-gray-900">
              Create Sale
            </Drawer.Title>
            <Drawer.Description className="leading-6 mt-2 text-sm text-gray-600">
              Configure a token sale with refund parameters and block timing.
            </Drawer.Description>
          <div className="mt-8 grid grid-cols-1 gap-8 lg:grid-cols-[2.2fr_1fr]">
            <div>
              <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
                <div>
                  <label htmlFor="sale-amount" className="text-sm font-semibold text-gray-900">
                    Amount
                  </label>
                  <Controller
                    name="amount"
                    control={control}
                    render={({ field }) => (
                      <Input
                        id="sale-amount"
                        type="text"
                        inputMode="decimal"
                        placeholder="100000"
                        className="mt-2 h-11 rounded-xl border-2 px-4 text-base"
                        value={formattedAmount}
                        onChange={(event) => {
                          const nextValue = event.target.value.replace(/,/g, "");
                          const sanitized = nextValue.replace(/[^0-9.]/g, "");
                          const [whole, ...rest] = sanitized.split(".");
                          const nextAmount = rest.length > 0 ? `${whole}.${rest.join("")}` : whole;
                          field.onChange(nextAmount);
                        }}
                      />
                    )}
                  />
                  <div className="mt-2 flex flex-wrap items-center justify-between gap-2 text-xs text-gray-500">
                    <span>
                      Max available:{" "}
                      {balanceStatus === "loading" ? "Loading..." : formattedContractBalance}{" "}
                      {tokenSymbol}
                    </span>
                    <button
                      type="button"
                      onClick={() => {
                        if (contractBalance === null) return;
                        setValue("amount", formatUnits(contractBalance, tokenDecimals), {
                          shouldDirty: true,
                          shouldTouch: true,
                        });
                      }}
                      className="font-semibold text-gray-700 hover:text-gray-900"
                    >
                      Use max
                    </button>
                  </div>
                </div>
                <div>
                  <label htmlFor="sale-price" className="text-sm font-semibold text-gray-900">
                    Price
                  </label>
                  <Input
                    id="sale-price"
                    type="number"
                    min="0"
                    step="any"
                    placeholder="0.05"
                    className="mt-2 h-11 rounded-xl border-2 px-4 text-base"
                    {...register("price")}
                  />
                  <div className="mt-2 text-xs text-gray-500 leading-relaxed">
                    <div>Price per token in the funding token.</div>
                    <div className="text-gray-600">
                      Expected raise: {expectedRaise ?? "—"}
                    </div>
                  </div>
                </div>
              </div>
              <div className="mt-8 grid grid-cols-1 gap-6 md:grid-cols-2">
                <div>
                  <label htmlFor="sale-start-time" className="text-sm font-semibold text-gray-900">
                    Start time
                  </label>
                  <input type="hidden" {...register("startDate")} />
                  <div className="mt-2 grid grid-cols-1 gap-3">
                    <Popover open={startPickerOpen} onOpenChange={setStartPickerOpen}>
                      <PopoverTrigger asChild>
                        <Button
                          id="sale-start-date"
                          variant="outline"
                          className={`h-11 w-full justify-between rounded-xl border-2 px-4 text-left text-base font-normal ${
                            !startDateValue ? "text-gray-500" : "text-gray-900"
                          }`}
                        >
                          <span className="flex items-center gap-2">
                            <CalendarIcon className="h-4 w-4 text-gray-500" />
                            {startDateValue ? format(startDateValue, "PPP") : "Select date"}
                          </span>
                          <ChevronDownIcon className="h-4 w-4 text-gray-400" />
                        </Button>
                      </PopoverTrigger>
                      <PopoverContent className="w-auto p-0" align="start">
                        <Calendar
                          mode="single"
                          selected={startDateValue}
                          captionLayout="dropdown"
                          defaultMonth={startDateValue}
                          onSelect={(date) => {
                            setValue("startDate", date ? date.toISOString() : null, {
                              shouldDirty: true,
                              shouldTouch: true,
                            });
                            setStartPickerOpen(false);
                          }}
                          initialFocus
                        />
                      </PopoverContent>
                    </Popover>
                    <Input
                      id="sale-start-time"
                      type="time"
                      step="1"
                      className="h-11 rounded-xl border-2 px-4 text-base bg-white appearance-none [&::-webkit-calendar-picker-indicator]:hidden [&::-webkit-calendar-picker-indicator]:appearance-none"
                      {...register("startTime")}
                    />
                  </div>
                </div>
                <div>
                  <label htmlFor="sale-end-time" className="text-sm font-semibold text-gray-900">
                    End time
                  </label>
                  <input type="hidden" {...register("endDate")} />
                  <div className="mt-2 grid grid-cols-1 gap-3">
                    <Popover open={endPickerOpen} onOpenChange={setEndPickerOpen}>
                      <PopoverTrigger asChild>
                        <Button
                          id="sale-end-date"
                          variant="outline"
                          className={`h-11 w-full justify-between rounded-xl border-2 px-4 text-left text-base font-normal ${
                            !endDateValue ? "text-gray-500" : "text-gray-900"
                          }`}
                        >
                          <span className="flex items-center gap-2">
                            <CalendarIcon className="h-4 w-4 text-gray-500" />
                            {endDateValue ? format(endDateValue, "PPP") : "Select date"}
                          </span>
                          <ChevronDownIcon className="h-4 w-4 text-gray-400" />
                        </Button>
                      </PopoverTrigger>
                      <PopoverContent className="w-auto p-0" align="start">
                        <Calendar
                          mode="single"
                          selected={endDateValue}
                          captionLayout="dropdown"
                          defaultMonth={endDateValue}
                          onSelect={(date) => {
                            setValue("endDate", date ? date.toISOString() : null, {
                              shouldDirty: true,
                              shouldTouch: true,
                            });
                            setEndPickerOpen(false);
                          }}
                          initialFocus
                        />
                      </PopoverContent>
                    </Popover>
                    <Input
                      id="sale-end-time"
                      type="time"
                      step="1"
                      className="h-11 rounded-xl border-2 px-4 text-base bg-white appearance-none [&::-webkit-calendar-picker-indicator]:hidden [&::-webkit-calendar-picker-indicator]:appearance-none"
                      {...register("endTime")}
                    />
                  </div>
                </div>
              </div>
              <div className="mt-8 grid grid-cols-1 gap-6 md:grid-cols-3">
                <div>
                  <label htmlFor="sale-refundable-bps" className="text-sm font-semibold text-gray-900">
                    Refundable %
                  </label>
                  <Input
                    id="sale-refundable-bps"
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    placeholder="80.00"
                    className="mt-2 h-11 rounded-xl border-2 px-4 text-base"
                    {...register("refundableBps")}
                  />
                  <p className="mt-2 text-xs text-gray-500">
                    Initial refundable percentage.
                  </p>
                </div>
                <div>
                  <label
                    htmlFor="sale-refundable-delay"
                    className="text-sm font-semibold text-gray-900"
                  >
                    Decay delay (blocks)
                  </label>
                  <Input
                    id="sale-refundable-delay"
                    type="number"
                    min="0"
                    placeholder="100"
                    className="mt-2 h-11 rounded-xl border-2 px-4 text-base"
                    {...register("decayDelay")}
                  />
                  <p className="mt-2 text-xs text-gray-500">
                    Blocks before refund decay starts.
                  </p>
                </div>
                <div>
                  <label
                    htmlFor="sale-refundable-duration"
                    className="text-sm font-semibold text-gray-900"
                  >
                    Decay duration (blocks)
                  </label>
                  <Input
                    id="sale-refundable-duration"
                    type="number"
                    min="0"
                    placeholder="200"
                    className="mt-2 h-11 rounded-xl border-2 px-4 text-base"
                    {...register("decayDuration")}
                  />
                  <p className="mt-2 text-xs text-gray-500">
                    Blocks until refunds are depleted.
                  </p>
                </div>
              </div>
              <Button
                className="mt-8 h-12 w-full rounded-xl text-base font-semibold"
                onClick={handleCreateSale}
                disabled={status === "submitting" || status === "pending"}
              >
                {status === "pending" ? "Creating sale..." : "Create Sale"}
              </Button>
              {error && (
                <div className="mt-3 text-sm text-red-600">
                  {error}
                </div>
              )}
              {status === "success" && (
                <div className="mt-3 text-sm text-emerald-600">
                  Sale created successfully.
                  {txHash ? ` Tx: ${txHash.slice(0, 10)}...` : ""}
                </div>
              )}
            </div>
            <aside className="rounded-2xl border border-gray-200 bg-gray-50 p-7">
              <div className="text-sm font-semibold text-gray-900">Sale summary</div>
              <div className="mt-4 space-y-4 text-sm text-gray-600">
                <div className="flex items-center justify-between">
                  <span>Token allocation</span>
                  <span className="font-semibold text-gray-900">
                    {formattedAmount || "—"} {tokenSymbol}
                  </span>
                </div>
                <div className="flex items-center justify-between">
                  <span>Price per token</span>
                  <span className="font-semibold text-gray-900">
                    {price || "—"} {fundingTokenSymbol}
                  </span>
                </div>
                <div className="flex items-center justify-between">
                  <span>Expected raise</span>
                  <span className="font-semibold text-gray-900">{expectedRaise ?? "—"}</span>
                </div>
                <div className="h-px bg-gray-200" />
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span>Start</span>
                    <span className="font-semibold text-gray-900">{formattedStartDateTime}</span>
                  </div>
                  <div className="flex items-center justify-between text-xs text-gray-500">
                    <span>Estimated block</span>
                    <span className="font-medium text-gray-700">{startBlock || "—"}</span>
                  </div>
                </div>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span>End</span>
                    <span className="font-semibold text-gray-900">{formattedEndDateTime}</span>
                  </div>
                  <div className="flex items-center justify-between text-xs text-gray-500">
                    <span>Estimated block</span>
                    <span className="font-medium text-gray-700">{endBlock || "—"}</span>
                  </div>
                </div>
                <div className="text-xs text-gray-500">
                  Average block time {averageBlockTimeSeconds}s.
                </div>
              </div>
            </aside>
          </div>
          </div>
        </Drawer.Content>
      </Drawer.Portal>
    </Drawer.Root>
  );
}
