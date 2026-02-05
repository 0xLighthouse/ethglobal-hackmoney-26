export const BASE_SEPOLIA_FACTORY_ADDRESS =
  (process.env.NEXT_PUBLIC_FACTORY_ADDRESS as `0x${string}` | undefined) ??
  "0xa12F5A16B2c84Fa4AA5443bF06E9f1c9A04246A9";


// TODO: For now just use USDC on Base Sepolia
export const BASE_SEPOLIA_FUNDING_TOKEN_ADDRESS =
  (process.env.NEXT_PUBLIC_FUNDING_TOKEN_ADDRESS as `0x${string}` | undefined) ??
  "0x036CbD53842c5426634e7929541eC2318f3dCF7e";
