# CrossChainLimitOrderHook

A Uniswap V4 hook that enables cross-chain limit orders for token swaps. This hook allows users to place limit orders that can be executed when the price conditions are met, with support for cross-chain execution.

## Features

- Place limit orders with specific price conditions
- Support for cross-chain order execution
- Automatic order expiration handling
- Integration with Uniswap V4's hook system
- Compatible with both ERC20 and native token pairs
- Gas-efficient order management
- Seamless integration with Optimism Superchain interop protocol

## Architecture

The hook consists of several key components:

1. **CrossChainLimitOrderHook**: The main hook contract that integrates with Uniswap V4's hook system
2. **OrderBook**: Manages the storage and execution of limit orders
3. **TokenCompatibilityChecker**: Ensures token compatibility across different chains

## Superchain Integration

The hook integrates with the Optimism Superchain interop protocol in several ways:

1. **Cross-Chain Message Passing**:
   - Uses the Superchain's message passing system to coordinate order execution across chains
   - Messages are sent via the `IMessageDispatcher` interface
   - Each chain maintains its own message queue for order execution

2. **Token Compatibility**:
   - Supports both SuperchainERC20 tokens and xERC20 tokens
   - SuperchainERC20 tokens can be bridged directly between chains
   - xERC20 tokens require additional bridging logic through the Superchain bridge

3. **Order Execution Flow**:
   ```
   Source Chain:
   1. Hook detects eligible order
   2. Checks token compatibility
   3. If compatible: Initiates token bridge
   4. If incompatible: Sends message to target chain
   
   Target Chain:
   1. Receives message or bridge confirmation
   2. Verifies order validity
   3. Executes order on target chain
   4. Sends confirmation back to source chain
   ```

4. **Security Measures**:
   - Message origin verification using Superchain's security model
   - Token bridge validation
   - Order state synchronization across chains

## Prerequisites

- Foundry
- Node.js
- Access to a Supersim instance (for testing)
  - [Supersim](https://github.com/ethereum-optimism/supersim) is a local multi-L2 development environment that simulates the Optimism Superchain ecosystem
  - Install via npm: `npm install -g @eth-optimism/supersim`
  - It enables testing cross-chain interactions locally

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd v4-template
```

2. Install dependencies:
```bash
forge install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

## Usage

### Deploying the Hook

1. Deploy the OrderBook contract:
```bash
forge script script/DeployOrderBook.s.sol:DeployOrderBook --rpc-url <your-rpc-url> --broadcast
```

2. Deploy the CrossChainLimitOrderHook:
```bash
forge script script/DeployHook.s.sol:DeployHook --rpc-url <your-rpc-url> --broadcast
```

### Creating a Limit Order

```solidity
// Example of creating a limit order
function createLimitOrder(
    address token0,
    address token1,
    uint256 amount0,
    uint256 amount1,
    uint256 deadline
) external {
    // Transfer tokens to the hook contract
    IERC20(token0).transferFrom(msg.sender, address(hook), amount0);
    
    // Create the order
    hook.createOrder(
        token0,
        token1,
        amount0,
        amount1,
        deadline
    );
}
```

### Testing

1. Start a local test environment with Supersim:
```bash
# Install Supersim if not already installed
npm install -g @eth-optimism/supersim

# Run Supersim with autorelay enabled for cross-chain testing
supersim --interop.autorelay
```

2. Run the test script:
```bash
forge script script/SimulateSwap.s.sol:SimulateSwap --rpc-url http://127.0.0.1:9545 --broadcast
```

3. For cross-chain testing:
```bash
# Chain 901 (first OP chain in Supersim)
forge script script/DeployHook.s.sol:DeployHook --rpc-url http://127.0.0.1:9545 --broadcast

# Chain 902 (second OP chain in Supersim)
forge script script/DeployHook.s.sol:DeployHook --rpc-url http://127.0.0.1:9546 --broadcast
```

## How It Works

1. **Order Creation**:
   - Users create limit orders by specifying token pairs, amounts, and deadlines
   - Orders are stored in the OrderBook contract

2. **Order Execution**:
   - The hook monitors swap events
   - When a swap occurs, it checks for eligible orders
   - Eligible orders are executed automatically

3. **Cross-Chain Support**:
   - Orders can be marked for cross-chain execution
   - The hook handles token compatibility checks
   - Orders can be executed on different chains

## Security Considerations

- The hook implements Uniswap V4's security model
- Orders can only be executed by the pool manager
- Token compatibility is verified before cross-chain execution
- Order expiration is enforced to prevent stale orders

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Example Use Case: Cross-Chain Arbitrage

Here's a practical example of how to use the hook for cross-chain arbitrage:

```solidity
// Example of creating a cross-chain arbitrage order
function createCrossChainArbitrageOrder(
    address token0,  // e.g., USDC on Optimism
    address token1,  // e.g., USDC on Base
    uint256 amount0,
    uint256 minAmount1,
    uint256 deadline
) external {
    // Transfer tokens to the hook contract
    IERC20(token0).transferFrom(msg.sender, address(hook), amount0);
    
    // Create the order with cross-chain execution enabled
    hook.createOrder(
        token0,
        token1,
        amount0,
        minAmount1,
        deadline,
        true  // enable cross-chain execution
    );
}
```

### Testing Cross-Chain Limit Orders with Supersim

You can use Supersim to test cross-chain limit orders locally:

1. Start Supersim with multiple chains and enable auto-relaying:
```bash
supersim --interop.autorelay
```

2. Deploy the hook contracts on both chains:
```bash
# Deploy to Chain 901
forge script script/DeployHook.s.sol:DeployHook --rpc-url http://127.0.0.1:9545 --broadcast

# Deploy to Chain 902 
forge script script/DeployHook.s.sol:DeployHook --rpc-url http://127.0.0.1:9546 --broadcast
```

3. Mint test SuperchainERC20 tokens:
```bash
# Using cast to mint tokens on Chain 901
cast send 0x420beeF000000000000000000000000000000001 "mint(address,uint256)" YOUR_ADDRESS 1000000000000000000 --rpc-url http://127.0.0.1:9545 --private-key YOUR_PRIVATE_KEY
```

4. Test cross-chain limit order:
```bash
# Create a limit order on Chain 901 targeting Chain 902
# This could be done through your own test script or UI
```

Supersim's auto-relay feature will automatically handle the message passing between chains.

### Example Scenario: USDC/USDT Arbitrage

1. **Setup**:
   - USDC/USDT pool on Optimism
   - USDC/USDT pool on Base
   - Price on Optimism: 1 USDC = 0.99 USDT
   - Price on Base: 1 USDC = 1.01 USDT

2. **Creating the Order**:
   ```solidity
   // Create an order to buy USDT on Optimism and sell on Base
   createCrossChainArbitrageOrder(
       USDC_OPTIMISM,  // token0
       USDT_BASE,      // token1
       1000 * 1e6,     // 1000 USDC
       1010 * 1e6,     // minimum 1010 USDT
       block.timestamp + 1 days
   );
   ```

3. **Execution Flow**:
   ```
   Optimism Chain:
   1. Hook detects USDC/USDT swap at 0.99 USDT per USDC
   2. Verifies token compatibility (USDC is bridgeable)
   3. Initiates token bridge to Base
   
   Base Chain:
   1. Receives bridged USDC
   2. Executes swap at 1.01 USDT per USDC
   3. Sends confirmation back to Optimism
   ```

4. **Profit Calculation**:
   - Initial: 1000 USDC on Optimism
   - After Optimism swap: 990 USDT
   - After bridging: 990 USDC on Base
   - After Base swap: 1000.1 USDT
   - Net profit: 10.1 USDT (minus gas and bridge fees)

### Benefits of Cross-Chain Execution

1. **Price Discovery**:
   - Access to liquidity across multiple chains
   - Better price execution through cross-chain arbitrage
   - Reduced slippage by splitting orders across chains

2. **Liquidity Efficiency**:
   - Orders can be filled from multiple liquidity pools
   - Reduced impact on individual pools
   - Better price stability across chains

3. **Risk Management**:
   - Diversification across chains
   - Reduced exposure to chain-specific issues
   - Better execution guarantees 