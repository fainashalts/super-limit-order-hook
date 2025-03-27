import { useState } from 'react';
import { useCreateOrder } from '../hooks/useLimitOrders';
import { useAccount, useNetwork } from 'wagmi';
import { mainnet, optimism } from 'wagmi/chains';

export function CreateOrderForm() {
  const { address } = useAccount();
  const { chain } = useNetwork();
  const { createOrder, isLoading, isSuccess, error } = useCreateOrder();

  const [formData, setFormData] = useState({
    tokenIn: '',
    tokenOut: '',
    amountIn: '',
    minAmountOut: '',
    expiry: '24',
    targetChains: [optimism.id],
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!address) return;

    await createOrder({
      tokenIn: formData.tokenIn as `0x${string}`,
      tokenOut: formData.tokenOut as `0x${string}`,
      amountIn: formData.amountIn,
      minAmountOut: formData.minAmountOut,
      expiry: formData.expiry,
      targetChains: formData.targetChains,
    });
  };

  if (!address) {
    return (
      <div className="p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
        <p className="text-yellow-800">Please connect your wallet to create orders</p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4 max-w-md mx-auto p-4">
      <div>
        <label className="block text-sm font-medium text-gray-700">Token In Address</label>
        <input
          type="text"
          value={formData.tokenIn}
          onChange={(e) => setFormData({ ...formData, tokenIn: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          placeholder="0x..."
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Token Out Address</label>
        <input
          type="text"
          value={formData.tokenOut}
          onChange={(e) => setFormData({ ...formData, tokenOut: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          placeholder="0x..."
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Amount In (ETH)</label>
        <input
          type="number"
          step="0.000000000000000001"
          value={formData.amountIn}
          onChange={(e) => setFormData({ ...formData, amountIn: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          placeholder="0.0"
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Minimum Amount Out (ETH)</label>
        <input
          type="number"
          step="0.000000000000000001"
          value={formData.minAmountOut}
          onChange={(e) => setFormData({ ...formData, minAmountOut: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          placeholder="0.0"
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Expiry (hours)</label>
        <input
          type="number"
          value={formData.expiry}
          onChange={(e) => setFormData({ ...formData, expiry: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Target Chains</label>
        <div className="mt-2 space-y-2">
          <label className="inline-flex items-center">
            <input
              type="checkbox"
              checked={formData.targetChains.includes(optimism.id)}
              onChange={(e) => {
                const newChains = e.target.checked
                  ? [...formData.targetChains, optimism.id]
                  : formData.targetChains.filter(id => id !== optimism.id);
                setFormData({ ...formData, targetChains: newChains });
              }}
              className="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
            <span className="ml-2">Optimism</span>
          </label>
        </div>
      </div>

      <button
        type="submit"
        disabled={isLoading}
        className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
      >
        {isLoading ? 'Creating Order...' : 'Create Order'}
      </button>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
          <p className="text-red-800">Error: {error.message}</p>
        </div>
      )}

      {isSuccess && (
        <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
          <p className="text-green-800">Order created successfully!</p>
        </div>
      )}
    </form>
  );
} 