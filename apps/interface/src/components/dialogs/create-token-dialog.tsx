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

export function CreateTokenDialog() {
  return (
    <Dialog>
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
                type="number"
                min="0"
                placeholder="1000000"
                className="h-12 rounded-xl border-2 px-4 text-base"
              />
              <p className="text-xs text-gray-500 mt-2">
                Total tokens that can ever be minted.
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
                  <div className="text-xs font-mono text-gray-500">0x...</div>
                </div>
              </div>
              <div className="ml-auto text-xs font-medium text-gray-500">Fixed</div>
            </div>
            <p className="text-xs text-gray-500 mt-2">
              Fixed to USDC on Base for funding.
            </p>
          </div>
          <Button className="h-12 w-full rounded-xl text-base font-semibold mt-6">
            Deploy Token
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
