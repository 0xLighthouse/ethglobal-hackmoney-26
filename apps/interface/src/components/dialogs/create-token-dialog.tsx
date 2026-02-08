'use client'

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { NetworkBase, TokenUSDC } from '@web3icons/react'
import { useMemo, useState } from 'react'
import { isAddress } from 'viem'
import { baseSepolia } from 'viem/chains'
import { ERC20RefundableTokenSaleFactoryABI } from '@repo/abis'
import {
  BASE_SEPOLIA_FACTORY_ADDRESS,
  BASE_SEPOLIA_FUNDING_TOKEN_ADDRESS
} from '@/config/constants'
import { useWeb3 } from '@/providers/web3'

export function CreateTokenDialog() {
  const { walletClient, publicClient, isInitialized } = useWeb3();
  const [open, setOpen] = useState(false)
  const [name, setName] = useState('')
  const [symbol, setSymbol] = useState('')
  const [maxSupply, setMaxSupply] = useState('')
  const [beneficiary, setBeneficiary] = useState('')
  const [status, setStatus] = useState<'idle' | 'submitting' | 'pending' | 'success' | 'error'>('idle')
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null)
  const [error, setError] = useState<string | null>(null)

  const fundingToken = useMemo(() => BASE_SEPOLIA_FUNDING_TOKEN_ADDRESS, [])
  const maxSupplyValue = useMemo(() => {
    if (!maxSupply) return null
    try {
      return BigInt(maxSupply)
    } catch {
      return null
    }
  }, [maxSupply])

  const formattedMaxSupply = useMemo(() => {
    if (!maxSupplyValue) return ''
    try {
      return new Intl.NumberFormat('en-US').format(maxSupplyValue)
    } catch {
      return maxSupply
    }
  }, [maxSupply, maxSupplyValue])

  const isFormValid =
    name.trim().length > 0 &&
    symbol.trim().length > 0 &&
    maxSupplyValue !== null &&
    maxSupplyValue > 0n &&
    isAddress(beneficiary) &&
    isAddress(fundingToken)

  const resetForm = () => {
    setName('')
    setSymbol('')
    setMaxSupply('')
    setBeneficiary('')
    setStatus('idle')
    setTxHash(null)
    setError(null)
  }

  const handleDeploy = async () => {
    setError(null)
    setTxHash(null)

    if (!walletClient || !isInitialized) {
      setError('Connect a wallet to deploy.')
      setStatus('error')
      return
    }

    if (!isFormValid) {
      setError('Fill in all fields with valid values.')
      setStatus('error')
      return
    }

    setStatus('submitting')

    try {
      const [account] = await walletClient.getAddresses()
      if (!account) {
        throw new Error('No wallet address available.')
      }

      const scaledMaxSupply = maxSupplyValue * 10n ** 18n

      const hash = await walletClient.writeContract({
        address: BASE_SEPOLIA_FACTORY_ADDRESS,
        abi: ERC20RefundableTokenSaleFactoryABI,
        functionName: 'deployRefundableToken',
        args: [
          name.trim(),
          symbol.trim(),
          scaledMaxSupply,
          beneficiary as `0x${string}`,
          fundingToken
        ],
        account
      })

      setTxHash(hash)
      setStatus('pending')

      await publicClient.waitForTransactionReceipt({ hash })
      setStatus('success')
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Deployment failed.'
      setError(message)
      setStatus('error')
    }
  }

  const handlePrimaryClick = () => {
    if (status === 'success') {
      setOpen(false)
      resetForm()
      return
    }
    if (status !== 'submitting' && status !== 'pending') {
      handleDeploy()
    }
  }

  const explorerBaseUrl = baseSepolia.blockExplorers?.default.url ?? 'https://sepolia.basescan.org'

  return (
    <Dialog
      open={open}
      onOpenChange={(nextOpen) => {
        setOpen(nextOpen)
        if (!nextOpen) {
          resetForm()
        }
      }}
    >
      <DialogTrigger asChild>
        <Button className="h-11 rounded-full px-5 text-sm font-semibold shadow-sm">
          Create Token
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl rounded-[24px] border-0 p-0 shadow-2xl">
        <div className="bg-white rounded-[24px] p-6 sm:p-8">
          <DialogTitle className="text-2xl font-semibold text-gray-900">
            Create Token
          </DialogTitle>
          <DialogDescription className="leading-6 mt-2 text-gray-600">
            Provide values to deploy a refundable token via the factory. The
            max supply and addresses are immutable after deployment.
          </DialogDescription>
          <div className="mt-8 grid grid-cols-1 gap-6 md:grid-cols-[1.2fr_0.8fr]">
            <div>
              <label htmlFor="token-name" className="font-semibold text-gray-900 text-sm mb-2 block">
                Name
              </label>
              <Input
                id="token-name"
                placeholder="Test Token"
                className="h-12 rounded-xl border-2 px-4 text-base"
                value={name}
                onChange={(event) => setName(event.target.value)}
              />
              <p className="text-xs text-gray-500 mt-2">
                Display name shown in wallets and interfaces.
              </p>
            </div>
            <div>
              <label htmlFor="token-symbol" className="font-semibold text-gray-900 text-sm mb-2 block">
                Symbol
              </label>
              <Input
                id="token-symbol"
                placeholder="TT"
                className="h-12 rounded-xl border-2 px-4 text-base md:max-w-[160px]"
                value={symbol}
                onChange={(event) => setSymbol(event.target.value)}
              />
              <p className="text-xs text-gray-500 mt-2">
                Short ticker, usually 2-5 characters.
              </p>
            </div>
          </div>
          <div className="mt-6 grid grid-cols-1 gap-6 md:grid-cols-2">
            <div>
              <label htmlFor="token-max-supply" className="font-semibold text-gray-900 text-sm mb-2 block">
                Max supply
              </label>
              <Input
                id="token-max-supply"
                type="text"
                inputMode="numeric"
                pattern="[0-9]*"
                placeholder="1000000"
                className="h-12 rounded-xl border-2 px-4 text-base"
                value={formattedMaxSupply}
                onChange={(event) => {
                  const digitsOnly = event.target.value.replace(/[^\d]/g, '')
                  setMaxSupply(digitsOnly)
                }}
              />
              <p className="text-xs text-gray-500 mt-2">
                Total tokens that can ever be minted. Scaled to 18 decimals.
              </p>
            </div>
            <div>
              <label htmlFor="token-beneficiary" className="font-semibold text-gray-900 text-sm mb-2 block">
                Beneficiary address
              </label>
              <Input
                id="token-beneficiary"
                placeholder="0x..."
                className="h-12 rounded-xl border-2 px-4 text-base"
                value={beneficiary}
                onChange={(event) => setBeneficiary(event.target.value)}
              />
              <p className="text-xs text-gray-500 mt-2">
                Address that receives the proceeds.
              </p>
            </div>
          </div>
          <div className="mt-6">
            <label htmlFor="token-funding-token" className="font-semibold text-gray-900 text-sm mb-2 block">
              Funding token
            </label>
            <div className="flex items-center gap-4 rounded-2xl border-2 border-gray-200 bg-white px-4 py-3">
              <div className="flex items-center gap-3">
                <div className="relative">
                  <TokenUSDC variant="branded" size={34} />
                  <div className="absolute -bottom-1 -right-1 rounded-full bg-white p-[1px]">
                    <NetworkBase variant="branded" size={16} />
                  </div>
                </div>
                <div>
                  <div className="text-sm font-semibold text-gray-900">USDC on Base</div>
                  <div className="text-xs font-mono text-gray-500">
                    {fundingToken}
                  </div>
                </div>
              </div>
              <div className="ml-auto text-xs font-medium text-gray-500">Fixed</div>
            </div>
            <p className="text-xs text-gray-500 mt-2">
              Fixed to USDC on Base for funding.
            </p>
          </div>
          {error && (
            <div className="mt-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {error}
            </div>
          )}
          {txHash && (
            <div className="mt-4 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
              <div className="flex items-center justify-between gap-3">
                <span>
                  {status === 'pending' ? 'Waiting for confirmation' : 'Confirmed'}:{' '}
                  <span className="font-mono">{txHash}</span>
                </span>
                <a
                  className="text-sm font-semibold text-emerald-700 underline"
                  href={`${explorerBaseUrl}/tx/${txHash}`}
                  target="_blank"
                  rel="noreferrer"
                >
                  View transaction
                </a>
              </div>
            </div>
          )}
          <Button
            className="h-12 w-full rounded-xl text-base font-semibold mt-6"
            onClick={handlePrimaryClick}
            disabled={
              (status === 'idle' && !isFormValid) ||
              status === 'submitting' ||
              status === 'pending'
            }
          >
            {status === 'submitting' && 'Deploying...'}
            {status === 'pending' && 'Confirming...'}
            {status === 'success' && 'Close'}
            {status === 'error' && 'Try Again'}
            {status === 'idle' && 'Deploy Token'}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
