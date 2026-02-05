import { baseSepolia } from "viem/chains";

export const AVERAGE_BLOCK_TIME_SECONDS_BY_CHAIN_ID: Record<number | "default", number> = {
  [baseSepolia.id]: 2,
  default: 2,
};
