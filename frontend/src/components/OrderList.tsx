import { useOrderDetails, useCancelOrder } from '../hooks/useLimitOrders';
import { OrderStatus } from '../config/contracts';
import { formatEther } from 'viem';
import { ethers } from 'ethers';

interface OrderListProps {
  orderIds: number[];
}

export function OrderList({ orderIds }: OrderListProps) {
  return (
    <div className="space-y-4">
      <h2 className="text-xl font-semibold text-gray-900">Your Orders</h2>
      <div className="grid gap-4">
        {orderIds.map((orderId) => (
          <OrderCard key={orderId} orderId={orderId} />
        ))}
      </div>
    </div>
  );
}

function OrderCard({ orderId }: { orderId: number }) {
  const { order, isLoading, error } = useOrderDetails(orderId);
  const { cancelOrder, isLoading: isCancelling } = useCancelOrder();

  if (isLoading) {
    return (
      <div className="p-4 bg-gray-50 border border-gray-200 rounded-lg animate-pulse">
        <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
        <div className="h-4 bg-gray-200 rounded w-1/2"></div>
      </div>
    );
  }

  if (error || !order) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
        <p className="text-red-800">Error loading order details</p>
      </div>
    );
  }

  const status = OrderStatus[order.status as unknown as keyof typeof OrderStatus];

  return (
    <div className="p-4 bg-white border border-gray-200 rounded-lg shadow-sm">
      <div className="flex justify-between items-start">
        <div>
          <h3 className="text-lg font-medium text-gray-900">Order #{orderId}</h3>
          <p className="text-sm text-gray-500">Status: {status}</p>
        </div>
        {order.status === OrderStatus.PENDING && (
          <button
            onClick={() => cancelOrder(orderId)}
            disabled={isCancelling}
            className="px-3 py-1 text-sm text-red-600 hover:text-red-800 disabled:opacity-50"
          >
            {isCancelling ? 'Cancelling...' : 'Cancel'}
          </button>
        )}
      </div>

      <div className="mt-4 space-y-2">
        <div className="flex justify-between">
          <span className="text-sm text-gray-500">Token In:</span>
          <span className="text-sm font-medium">{order.tokenIn}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-sm text-gray-500">Token Out:</span>
          <span className="text-sm font-medium">{order.tokenOut}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-sm text-gray-500">Amount In:</span>
          <span className="text-sm font-medium">
            {formatEther(BigInt(order.amountIn.toString()))} ETH
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-sm text-gray-500">Min Amount Out:</span>
          <span className="text-sm font-medium">
            {formatEther(BigInt(order.minAmountOut.toString()))} ETH
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-sm text-gray-500">Expiry:</span>
          <span className="text-sm font-medium">
            {new Date(Number(order.expiry) * 1000).toLocaleString()}
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-sm text-gray-500">Target Chains:</span>
          <span className="text-sm font-medium">
            {order.targetChains.map(chainId => chainId.toString()).join(', ')}
          </span>
        </div>
      </div>
    </div>
  );
} 