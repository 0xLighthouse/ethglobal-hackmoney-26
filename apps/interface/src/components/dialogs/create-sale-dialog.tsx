import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export function CreateSaleDialog() {
  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button className="h-11 rounded-full px-5 text-sm font-semibold shadow-sm">
          Create Sale
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-2xl rounded-[24px] border-0 p-0 shadow-2xl">
        <div className="bg-white rounded-[24px] p-6 sm:p-8">
          <DialogTitle className="text-2xl font-semibold text-gray-900">
            Create Sale
          </DialogTitle>
          <DialogDescription className="leading-6 mt-2 text-gray-600">
            Configure a token sale with refund parameters and block timing.
          </DialogDescription>
          <div className="mt-8 grid grid-cols-1 gap-6 md:grid-cols-2">
            <div>
              <label htmlFor="sale-amount" className="font-semibold text-gray-900 text-sm mb-2 block">
                Amount
              </label>
              <Input
                id="sale-amount"
                type="number"
                min="0"
                placeholder="100000"
                className="h-12 rounded-xl border-2 px-4 text-base"
              />
              <p className="text-xs text-gray-500 mt-2">
                Total tokens allocated to the sale.
              </p>
            </div>
            <div>
              <label htmlFor="sale-price" className="font-semibold text-gray-900 text-sm mb-2 block">
                Price
              </label>
              <Input
                id="sale-price"
                type="number"
                min="0"
                step="any"
                placeholder="0.05"
                className="h-12 rounded-xl border-2 px-4 text-base"
              />
              <p className="text-xs text-gray-500 mt-2">
                Price per token in the funding token.
              </p>
            </div>
          </div>
          <div className="mt-6 grid grid-cols-1 gap-6 md:grid-cols-2">
            <div>
              <label htmlFor="sale-start-block" className="font-semibold text-gray-900 text-sm mb-2 block">
                Start block
              </label>
              <Input
                id="sale-start-block"
                type="number"
                min="0"
                placeholder="12345678"
                className="h-12 rounded-xl border-2 px-4 text-base"
              />
              <p className="text-xs text-gray-500 mt-2">
                Block number when the sale opens.
              </p>
            </div>
            <div>
              <label htmlFor="sale-end-block" className="font-semibold text-gray-900 text-sm mb-2 block">
                End block
              </label>
              <Input
                id="sale-end-block"
                type="number"
                min="0"
                placeholder="12349999"
                className="h-12 rounded-xl border-2 px-4 text-base"
              />
              <p className="text-xs text-gray-500 mt-2">
                Block number when the sale closes.
              </p>
            </div>
          </div>
          <div className="mt-6 grid grid-cols-1 gap-6 md:grid-cols-3">
            <div>
              <label htmlFor="sale-refundable-bps" className="font-semibold text-gray-900 text-sm mb-2 block">
                Refundable %
              </label>
              <Input
                id="sale-refundable-bps"
                type="number"
                min="0"
                max="100"
                step="0.01"
                placeholder="80.00"
                className="h-12 rounded-xl border-2 px-4 text-base"
              />
              <p className="text-xs text-gray-500 mt-2">
                Initial refundable percentage.
              </p>
            </div>
            <div>
              <label
                htmlFor="sale-refundable-delay"
                className="font-semibold text-gray-900 text-sm mb-2 block"
              >
                Decay delay (blocks)
              </label>
              <Input
                id="sale-refundable-delay"
                type="number"
                min="0"
                placeholder="100"
                className="h-12 rounded-xl border-2 px-4 text-base"
              />
              <p className="text-xs text-gray-500 mt-2">
                Blocks before refund decay starts.
              </p>
            </div>
            <div>
              <label
                htmlFor="sale-refundable-duration"
                className="font-semibold text-gray-900 text-sm mb-2 block"
              >
                Decay duration (blocks)
              </label>
              <Input
                id="sale-refundable-duration"
                type="number"
                min="0"
                placeholder="200"
                className="h-12 rounded-xl border-2 px-4 text-base"
              />
              <p className="text-xs text-gray-500 mt-2">
                Blocks until refunds are depleted.
              </p>
            </div>
          </div>
          <Button className="h-12 w-full rounded-xl text-base font-semibold mt-6">
            Create Sale
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
