import { useEffect, useState } from 'react';
import { useContractEvent, useNetwork } from 'wagmi';
import { HOOK_ADDRESSES, HOOK_ABI } from '../config/contracts';
import { type Address, type Log } from 'viem';

type OrderEventName = 'OrderCreated' | 'OrderCancelled' | 'OrderFilled' | 'OrderExpired';

interface OrderEventLog extends Log {
  args: {
    orderId: bigint;
  };
}

export function useOrderTracking() {
  const { chain } = useNetwork();
  const [orderIds, setOrderIds] = useState<number[]>([]);
  const hookAddress = chain?.id ? (HOOK_ADDRESSES[chain.id] as Address) : undefined;

  // Listen for OrderCreated events
  useContractEvent({
    address: hookAddress,
    abi: HOOK_ABI,
    eventName: 'OrderCreated' as OrderEventName,
    listener(...args) {
      const [orderId] = args;
      setOrderIds(prev => Array.from(new Set([...prev, Number(orderId)])));
    },
  });

  // Listen for OrderCancelled events
  useContractEvent({
    address: hookAddress,
    abi: HOOK_ABI,
    eventName: 'OrderCancelled' as OrderEventName,
    listener(...args) {
      const [orderId] = args;
      setOrderIds(prev => prev.filter(id => id !== Number(orderId)));
    },
  });

  // Listen for OrderFilled events
  useContractEvent({
    address: hookAddress,
    abi: HOOK_ABI,
    eventName: 'OrderFilled' as OrderEventName,
    listener(...args) {
      const [orderId] = args;
      setOrderIds(prev => prev.filter(id => id !== Number(orderId)));
    },
  });

  // Listen for OrderExpired events
  useContractEvent({
    address: hookAddress,
    abi: HOOK_ABI,
    eventName: 'OrderExpired' as OrderEventName,
    listener(...args) {
      const [orderId] = args;
      setOrderIds(prev => prev.filter(id => id !== Number(orderId)));
    },
  });

  return orderIds;
} 