// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "../../lib/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "../../lib/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "../../lib/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "../../lib/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "../../lib/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "../../lib/v4-core/src/types/Currency.sol";
import {IHooks} from "../../lib/v4-core/src/interfaces/IHooks.sol";

import {OrderBook} from "../../src/OrderBook.sol";
import {TokenCompatibilityChecker} from "../../src/TokenCompatibilityChecker.sol";

/**
 * @title TestCrossChainLimitOrderHook
 * @notice A simplified test version of CrossChainLimitOrderHook for direct testing
 */
contract TestCrossChainLimitOrderHook {
    // ============ Constants ============
    uint256 private constant PRECISION = 1e18;
    
    // ============ State Variables ============
    IPoolManager public immutable poolManager;
    OrderBook public immutable orderBook;
    TokenCompatibilityChecker public immutable tokenChecker;
    
    // ============ Events ============
    event LimitOrderExecuted(
        uint256 indexed orderId,
        uint256 executionChainId,
        uint256 amountIn,
        uint256 amountOut
    );
    
    // ============ Constructor ============
    constructor(
        IPoolManager _poolManager,
        address _orderBookAddress,
        address _tokenCheckerAddress
    ) {
        poolManager = _poolManager;
        orderBook = OrderBook(_orderBookAddress);
        tokenChecker = TokenCompatibilityChecker(_tokenCheckerAddress);
    }

    /**
     * @notice Creates a test limit order
     * @param owner The owner of the order
     * @param tokenIn The token to sell
     * @param tokenOut The token to buy
     * @param amountIn The amount of tokenIn to sell
     * @param minAmountOut The minimum amount of tokenOut to receive
     * @param expiry The timestamp when the order expires
     * @return orderId The ID of the created order
     */
    function createTestOrder(
        address owner,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 expiry
    ) external returns (uint256) {
        uint256[] memory targetChains = new uint256[](1);
        targetChains[0] = block.chainid;
        
        return orderBook.createOrder(
            owner,
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            expiry,
            targetChains
        );
    }

    /**
     * @notice Simulates the afterSwap hook for testing
     * @param sender The sender of the swap
     * @param key The pool key
     * @param params The swap parameters
     * @param delta The balance delta
     * @param hookData Additional data for the hook
     * @return selector The function selector
     * @return deltaAmount The delta amount
     */
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4 selector, int128 deltaAmount) {
        // Calculate the price based on the tokens involved in the swap
        uint256 price = calculatePrice(key, params, delta);
        
        // Log the price for debugging
        console.log("Calculated price:", price);
        
        // Check if any limit orders can be executed with this price
        // Since we don't have a getActiveOrderIds method, we'll use the token pair from the swap
        address tokenIn = params.zeroForOne ? Currency.unwrap(key.currency0) : Currency.unwrap(key.currency1);
        address tokenOut = params.zeroForOne ? Currency.unwrap(key.currency1) : Currency.unwrap(key.currency0);
        
        uint256[] memory orderIds = orderBook.getEligibleOrders(tokenIn, tokenOut);
        
        console.log("Number of eligible orders:", orderIds.length);
        
        for (uint256 i = 0; i < orderIds.length; i++) {
            uint256 orderId = orderIds[i];
            OrderBook.Order memory order = orderBook.getOrder(orderId);
            
            // Check if the order can be executed at this price
            if (canExecuteOrder(order, price)) {
                // Execute the order
                executeOrder(orderId, price);
            }
        }
        
        return (IHooks.afterSwap.selector, 0);
    }
    
    /**
     * @notice Calculates the price based on the swap
     * @param key The pool key
     * @param params The swap parameters
     * @param delta The balance delta
     * @return The calculated price
     */
    function calculatePrice(
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta
    ) internal pure returns (uint256) {
        // For simplicity, we'll use a 1:1 price in this test
        return PRECISION;
    }
    
    /**
     * @notice Checks if an order can be executed at the given price
     * @param order The order to check
     * @param price The current price
     * @return Whether the order can be executed
     */
    function canExecuteOrder(OrderBook.Order memory order, uint256 price) internal view returns (bool) {
        // Check if the order is active
        if (order.status != OrderBook.OrderStatus.ACTIVE) {
            return false;
        }
        
        // Check if the order has expired
        if (order.expiry <= block.timestamp) {
            return false;
        }
        
        // Calculate the amount out based on the price
        uint256 amountOut = (order.amountIn * PRECISION) / price;
        
        // Check if the amount out meets the minimum requirement
        return amountOut >= order.minAmountOut;
    }
    
    /**
     * @notice Executes an order
     * @param orderId The ID of the order to execute
     * @param price The execution price
     */
    function executeOrder(uint256 orderId, uint256 price) internal {
        OrderBook.Order memory order = orderBook.getOrder(orderId);
        
        // Calculate the amount out based on the price
        uint256 amountOut = (order.amountIn * PRECISION) / price;
        
        // Update the order status
        orderBook.executeOrder(orderId);
        
        // Emit the event
        emit LimitOrderExecuted(
            orderId,
            block.chainid,
            order.amountIn,
            amountOut
        );
    }
}

// Helper for logging
library console {
    function log(string memory message, uint256 value) internal view {
        // This is a placeholder for actual logging
    }
    
    function log(string memory message) internal view {
        // This is a placeholder for actual logging
    }
}