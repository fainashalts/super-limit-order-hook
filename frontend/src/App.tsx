import { ConnectButton } from '@rainbow-me/rainbowkit';
import { CreateOrderForm } from './components/CreateOrderForm';
import { OrderList } from './components/OrderList';
import { useOrderTracking } from './hooks/useOrderTracking';

function App() {
  const orderIds = useOrderTracking();

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center">
            <h1 className="text-3xl font-bold text-gray-900">Cross-Chain Limit Orders</h1>
            <ConnectButton />
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
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
