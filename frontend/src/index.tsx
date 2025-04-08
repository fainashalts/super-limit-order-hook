import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import { WagmiConfig, createClient, configureChains } from 'wagmi';
import { mainnet, optimism } from 'wagmi/chains';
import { publicProvider } from 'wagmi/providers/public';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { RainbowKitProvider, getDefaultWallets, darkTheme } from '@rainbow-me/rainbowkit';
import '@rainbow-me/rainbowkit/styles.css';
import { ethers } from 'ethers';

const { chains, provider } = configureChains(
  [mainnet, optimism],
  [publicProvider()]
);

const { connectors } = getDefaultWallets({
  appName: 'Cross Chain Limit Order Hook',
  chains,
});

const wagmiClient = createClient({
  autoConnect: true,
  connectors,
  provider,
});

const queryClient = new QueryClient();

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <React.StrictMode>
    <WagmiConfig client={wagmiClient}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider 
          chains={chains}
          theme={darkTheme({
            accentColor: '#7C3AED',
            accentColorForeground: 'white',
            borderRadius: 'large',
            fontStack: 'system',
            overlayBlur: 'small',
          })}
        >
          <App />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiConfig>
  </React.StrictMode>
);
