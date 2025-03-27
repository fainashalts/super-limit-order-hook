import { optimism } from 'wagmi/chains'

// Define Unichain configuration
const unichain = {
  id: 130,
  name: 'Unichain',
  network: 'unichain',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:9546'] },
    public: { http: ['http://127.0.0.1:9546'] },
  },
  blockExplorers: {
    default: { name: 'Unichain Explorer', url: 'http://localhost:3000' },
  },
  testnet: false,
}

// Configure Optimism mainnet with custom RPC
const optimismMainnet = {
  ...optimism,
  rpcUrls: {
    ...optimism.rpcUrls,
    default: { http: ['http://127.0.0.1:9545'] },
    public: { http: ['http://127.0.0.1:9545'] },
  },
}

export const supportedChains = [optimismMainnet, unichain]
export const defaultChain = optimismMainnet 