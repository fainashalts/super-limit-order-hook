import { useContractWrite, useContractRead, useWaitForTransaction, useNetwork } from 'wagmi';
import { HOOK_ADDRESSES, HOOK_ABI } from '../config/contracts';
import { type Address } from 'viem';
import { ethers } from 'ethers';

export function useCreateOrder() {
  const { chain } = useNetwork();
  const hookAddress = chain?.id ? HOOK_ADDRESSES[chain.id] as Address : undefined;

  const { data, write, isLoading, error } = useContractWrite({
    address: hookAddress,
    abi: HOOK_ABI,
    functionName: 'createLimitOrder',
    mode: 'recklesslyUnprepared',
  });

  const { isLoading: isConfirming } = useWaitForTransaction({
    hash: data?.hash,
  });

  const createOrder = async (params: {
    tokenIn: Address;
    tokenOut: Address;
    amountIn: string;
    minAmountOut: string;
    expiry: string;
    targetChains: number[];
  }) => {
    if (!write) return;

    const expiry = Math.floor(Date.now() / 1000) + Number(params.expiry) * 3600;

    write({
      recklesslySetUnpreparedArgs: [
        params.tokenIn,
        params.tokenOut,
        ethers.utils.parseEther(params.amountIn),
        ethers.utils.parseEther(params.minAmountOut),
        ethers.BigNumber.from(expiry),
        params.targetChains.map(chainId => ethers.BigNumber.from(chainId)),
      ],
    });
  };

  return {
    createOrder,
    isLoading: isLoading || isConfirming,
    isSuccess: !!data?.hash,
    error,
  };
}

export function useCancelOrder() {
  const { chain } = useNetwork();
  const hookAddress = chain?.id ? HOOK_ADDRESSES[chain.id] as Address : undefined;

  const { data, write, isLoading, error } = useContractWrite({
    address: hookAddress,
    abi: HOOK_ABI,
    functionName: 'cancelLimitOrder',
    mode: 'recklesslyUnprepared',
  });

  const { isLoading: isConfirming } = useWaitForTransaction({
    hash: data?.hash,
  });

  const cancelOrder = async (orderId: number) => {
    if (!write) return;

    write({
      recklesslySetUnpreparedArgs: [ethers.BigNumber.from(orderId)],
    });
  };

  return {
    cancelOrder,
    isLoading: isLoading || isConfirming,
    isSuccess: !!data?.hash,
    error,
  };
}

export function useOrderDetails(orderId: number) {
  const { chain } = useNetwork();
  const hookAddress = chain?.id ? HOOK_ADDRESSES[chain.id] as Address : undefined;

  const { data: order, isLoading, error } = useContractRead({
    address: hookAddress,
    abi: HOOK_ABI,
    functionName: 'getOrderDetails',
    args: [ethers.BigNumber.from(orderId)],
    enabled: !!hookAddress && orderId > 0,
  });

  return {
    order,
    isLoading,
    error,
  };
} 