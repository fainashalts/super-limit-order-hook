import React from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { CreateOrderForm } from './components/CreateOrderForm';
import { OrderList } from './components/OrderList';
import { useOrderTracking } from './hooks/useOrderTracking';
import './App.css';

function App() {
  const orderIds = useOrderTracking();

  return (
    <div className="App">
      <header className="App-header">
        <h1>Cross Chain Limit Order Hook</h1>
        <div className="wallet-connect">
          <ConnectButton />
        </div>
      </header>
      <main className="App-main">
        <div className="px-4 py-6 sm:px-0">
          <div className="cross-chain-info">
            <h2>How It Works</h2>
            <div className="chain-explanation">
              <div className="chain-card">
                <h3>1. Create Order</h3>
                <p>Set up your limit order on Unichain</p>
                <ul>
                  <li>Select token pair to trade</li>
                  <li>Set your target price</li>
                  <li>Specify order amount</li>
                  <li>Choose execution deadline</li>
                </ul>
              </div>
              <div className="chain-arrow">→</div>
              <div className="chain-card">
                <h3>2. Order Execution</h3>
                <p>Your order will be executed on OP Mainnet</p>
                <ul>
                  <li>Order is monitored for price conditions</li>
                  <li>When price target is met, order executes</li>
                  <li>Tokens are swapped automatically</li>
                  <li>Transaction completed on OP Mainnet</li>
                </ul>
              </div>
            </div>
          </div>

          <div className="grid gap-8">
            <div>
              <h2 className="text-2xl font-semibold text-gray-900 mb-4">Create New Order</h2>
              <CreateOrderForm />
            </div>

            <div>
              <OrderList orderIds={orderIds} />
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

export default App;
