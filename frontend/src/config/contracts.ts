import { mainnet, optimism } from 'wagmi/chains';
import { type Address } from 'viem';

// Contract addresses for each chain
export const HOOK_ADDRESSES: Record<number, Address> = {
  [mainnet.id]: '0x0000000000000000000000000000000000000000' as Address, // Replace with actual deployed address on mainnet
  [optimism.id]: '0x0000000000000000000000000000000000000000' as Address, // Replace with actual deployed address on optimism
};

// ABI for the limit order hook contract
export const HOOK_ABI = [
  {
    inputs: [
      { name: 'tokenIn', type: 'address' },
      { name: 'tokenOut', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'minAmountOut', type: 'uint256' },
      { name: 'expiry', type: 'uint256' },
      { name: 'targetChains', type: 'uint256[]' },
    ],
    name: 'createLimitOrder',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'orderId', type: 'uint256' }],
    name: 'cancelLimitOrder',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'orderId', type: 'uint256' }],
    name: 'getOrderDetails',
    outputs: [
      { name: 'id', type: 'uint256' },
      { name: 'tokenIn', type: 'address' },
      { name: 'tokenOut', type: 'address' },
      { name: 'amountIn', type: 'uint256' },
      { name: 'minAmountOut', type: 'uint256' },
      { name: 'expiry', type: 'uint256' },
      { name: 'targetChains', type: 'uint256[]' },
      { name: 'status', type: 'uint8' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'orderId', type: 'uint256' },
      { indexed: true, name: 'tokenIn', type: 'address' },
      { indexed: true, name: 'tokenOut', type: 'address' },
      { indexed: false, name: 'amountIn', type: 'uint256' },
      { indexed: false, name: 'minAmountOut', type: 'uint256' },
      { indexed: false, name: 'expiry', type: 'uint256' },
      { indexed: false, name: 'targetChains', type: 'uint256[]' },
    ],
    name: 'OrderCreated',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [{ indexed: true, name: 'orderId', type: 'uint256' }],
    name: 'OrderCancelled',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [{ indexed: true, name: 'orderId', type: 'uint256' }],
    name: 'OrderFilled',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [{ indexed: true, name: 'orderId', type: 'uint256' }],
    name: 'OrderExpired',
    type: 'event',
  },
] as const;

// Order status enum
export enum OrderStatus {
  PENDING = 0,
  FILLED = 1,
  CANCELLED = 2,
  EXPIRED = 3,
} 