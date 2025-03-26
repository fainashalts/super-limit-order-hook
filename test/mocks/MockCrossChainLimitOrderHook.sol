// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockBaseHook} from "../utils/MockBaseHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

import {ICrossL2Inbox} from "../../src/interfaces/ICrossL2Inbox.sol";
import {ISuperchainTokenBridge} from "../../src/interfaces/ISuperchainTokenBridge.sol";
import {OrderBook} from "../../src/OrderBook.sol";
import {TokenCompatibilityChecker} from "../../src/TokenCompatibilityChecker.sol";

/**
 * @title MockCrossChainLimitOrderHook
 * @notice A mock version of CrossChainLimitOrderHook for testing
 */
contract MockCrossChainLimitOrderHook is MockBaseHook, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============
    uint256 private constant PRECISION = 1e18;
    bytes32 private constant ORDER_EXECUTION_MESSAGE_TYPE = keccak256("CROSS_CHAIN_LIMIT_ORDER_EXECUTION");
    
    // ============ State Variables ============
    ICrossL2Inbox public immutable inbox;
    ISuperchainTokenBridge public immutable bridge;
    OrderBook public immutable orderBook;
    TokenCompatibilityChecker public immutable tokenChecker;
    
    // Mapping to track cross-chain messages
    mapping(bytes32 => bool) public processedMessages;
    
    // ============ Events ============
    event LimitOrderCreated(
        uint256 indexed orderId,
        address indexed owner,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 expiry,
        uint256[] targetChains
    );
    
    event LimitOrderExecuted(
        uint256 indexed orderId,
        uint256 executionChainId,
        uint256 amountIn,
        uint256 amountOut
    );
    
    event LimitOrderCancelled(
        uint256 indexed orderId
    );
    
    event CrossChainExecutionInitiated(
        uint256 indexed orderId,
        uint256 targetChainId,
        bytes32 messageHash
    );
    
    event CrossChainExecutionCompleted(
        uint256 indexed orderId,
        uint256 sourceChainId,
        bytes32 messageHash
    );

    // ============ Errors ============
    error OrderExpired();
    error OrderNotFound();
    error OrderAlreadyExecuted();
    error OrderAlreadyCancelled();
    error Unauthorized();
    error InvalidAmount();
    error InvalidExpiry();
    error MessageAlreadyProcessed();
    error InvalidMessageSender();
    error TokenNotSupported();
    error BridgeOperationFailed();
    error SwapFailed();

    // ============ Constructor ============
    constructor(
        IPoolManager _poolManager,
        address _orderBookAddress,
        address _tokenCheckerAddress,
        address _inboxAddress,
        address _bridgeAddress
    ) MockBaseHook(_poolManager) {
        inbox = ICrossL2Inbox(_inboxAddress);
        bridge = ISuperchainTokenBridge(_bridgeAddress);
        orderBook = OrderBook(_orderBookAddress);
        tokenChecker = TokenCompatibilityChecker(_tokenCheckerAddress);
    }

    // ============ Hook Configuration ============
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // ============ External Functions ============
    
    /**
     * @notice Creates a new limit order
     * @param tokenIn The token to sell
     * @param tokenOut The token to buy
     * @param amountIn The amount of tokenIn to sell
     * @param minAmountOut The minimum amount of tokenOut to receive
     * @param expiry The timestamp when the order expires
     * @param targetChains Array of chain IDs to monitor for execution
     * @return orderId The ID of the created order
     */
    function createLimitOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 expiry,
        uint256[] calldata targetChains
    ) external nonReentrant returns (uint256 orderId) {
        if (amountIn == 0) revert InvalidAmount();
        if (expiry <= block.timestamp) revert InvalidExpiry();
        
        // Transfer tokens from user to this contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        // Create the order in the order book
        orderId = orderBook.createOrder(
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            expiry,
            targetChains
        );
        
        emit LimitOrderCreated(
            orderId,
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            expiry,
            targetChains
        );
        
        return orderId;
    }
    
    /**
     * @notice Cancels an existing limit order
     * @param orderId The ID of the order to cancel
     */
    function cancelLimitOrder(uint256 orderId) external nonReentrant {
        OrderBook.Order memory order = orderBook.getOrder(orderId);
        
        if (order.owner != msg.sender) revert Unauthorized();
        if (order.status == OrderBook.OrderStatus.EXECUTED) revert OrderAlreadyExecuted();
        if (order.status == OrderBook.OrderStatus.CANCELLED) revert OrderAlreadyCancelled();
        
        // Update order status
        orderBook.cancelOrder(orderId);
        
        // Return tokens to the user
        IERC20(order.tokenIn).safeTransfer(order.owner, order.amountIn);
        
        emit LimitOrderCancelled(orderId);
    }
    
    /**
     * @notice Processes a cross-chain message for order execution
     * @param id The identifier of the cross-chain message
     * @param msgHash The hash of the message
     * @param orderId The ID of the order to execute
     */
    function processCrossChainExecution(
        ICrossL2Inbox.Identifier calldata id,
        bytes32 msgHash,
        uint256 orderId
    ) external nonReentrant {
        // Validate the message
        inbox.validateMessage(id, msgHash);
        
        // Check if message has already been processed
        if (processedMessages[msgHash]) revert MessageAlreadyProcessed();
        
        // Mark message as processed
        processedMessages[msgHash] = true;
        
        // Execute the order locally
        _executeOrder(orderId);
        
        emit CrossChainExecutionCompleted(orderId, id.chainId, msgHash);
    }
    
    /**
     * @notice Gets the status of an order
     * @param orderId The ID of the order
     * @return The status of the order
     */
    function getOrderStatus(uint256 orderId) external view returns (OrderBook.OrderStatus) {
        return orderBook.getOrderStatus(orderId);
    }
    
    /**
     * @notice Gets the details of an order
     * @param orderId The ID of the order
     * @return The order details
     */
    function getOrderDetails(uint256 orderId) external view returns (OrderBook.Order memory) {
        return orderBook.getOrder(orderId);
    }

    // ============ Hook Callbacks ============
    
    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        // This hook is used to check prices before swaps
        // Implementation will depend on specific price monitoring strategy
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }
    
    function _afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        // Get the tokens involved in the swap
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        
        // Calculate the current price
        // This is a simplified calculation and would need to be more robust in production
        uint256 price;
        address tokenIn;
        address tokenOut;
        
        if (params.zeroForOne) {
            // Selling token0 for token1
            tokenIn = token0;
            tokenOut = token1;
            // Convert delta to positive values for calculation
            uint256 amountIn = uint256(int256(-delta.amount0()));
            uint256 amountOut = uint256(int256(delta.amount1()));
            if (amountIn > 0) {
                price = (amountOut * PRECISION) / amountIn;
            }
        } else {
            // Selling token1 for token0
            tokenIn = token1;
            tokenOut = token0;
            // Convert delta to positive values for calculation
            uint256 amountIn = uint256(int256(-delta.amount1()));
            uint256 amountOut = uint256(int256(delta.amount0()));
            if (amountIn > 0) {
                price = (amountOut * PRECISION) / amountIn;
            }
        }
        
        // Check if any limit orders can be executed with this price
        _checkAndExecuteOrders(tokenIn, tokenOut, price);
        
        return (IHooks.afterSwap.selector, 0);
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Checks if any limit orders can be executed at the current price
     * @param tokenIn The input token
     * @param tokenOut The output token
     * @param price The current price (amountOut/amountIn) scaled by PRECISION
     */
    function _checkAndExecuteOrders(
        address tokenIn,
        address tokenOut,
        uint256 price
    ) internal {
        // Get eligible orders for this token pair
        uint256[] memory orderIds = orderBook.getEligibleOrders(tokenIn, tokenOut);
        
        for (uint256 i = 0; i < orderIds.length; i++) {
            uint256 orderId = orderIds[i];
            OrderBook.Order memory order = orderBook.getOrder(orderId);
            
            // Skip if order is not active
            if (order.status != OrderBook.OrderStatus.ACTIVE) continue;
            
            // Skip if order is expired
            if (order.expiry <= block.timestamp) {
                orderBook.expireOrder(orderId);
                continue;
            }
            
            // Calculate the expected output amount at current price
            uint256 expectedOut = (order.amountIn * price) / PRECISION;
            
            // Check if the price meets the order's requirements
            if (expectedOut >= order.minAmountOut) {
                // Check if this is the best chain to execute on
                if (_shouldExecuteOnThisChain(order)) {
                    // Execute the order locally
                    _executeOrder(orderId);
                } else {
                    // Initiate cross-chain execution
                    _initiateCrossChainExecution(orderId);
                }
            }
        }
    }
    
    /**
     * @notice Determines if an order should be executed on this chain
     * @param order The order to check
     * @return True if the order should be executed on this chain
     */
    function _shouldExecuteOnThisChain(OrderBook.Order memory order) internal view returns (bool) {
        // Check if this chain is in the target chains
        bool isTargetChain = false;
        for (uint256 i = 0; i < order.targetChains.length; i++) {
            if (order.targetChains[i] == block.chainid) {
                isTargetChain = true;
                break;
            }
        }
        
        // If this chain is not a target, don't execute here
        if (!isTargetChain) return false;
        
        // For now, we'll use a simple strategy: execute on the current chain if it's a target
        // In a more sophisticated implementation, we would compare prices across chains
        return true;
    }
    
    /**
     * @notice Executes a limit order
     * @param orderId The ID of the order to execute
     */
    function _executeOrder(uint256 orderId) internal {
        OrderBook.Order memory order = orderBook.getOrder(orderId);
        
        // Verify order can be executed
        if (order.status == OrderBook.OrderStatus.EXECUTED) revert OrderAlreadyExecuted();
        if (order.status == OrderBook.OrderStatus.CANCELLED) revert OrderAlreadyCancelled();
        if (order.expiry <= block.timestamp) revert OrderExpired();
        
        // Mark order as executed
        orderBook.executeOrder(orderId);
        
        // Perform the swap
        uint256 amountOut = _performSwap(order.tokenIn, order.tokenOut, order.amountIn, order.minAmountOut);
        
        // Transfer the output tokens to the order owner
        IERC20(order.tokenOut).safeTransfer(order.owner, amountOut);
        
        emit LimitOrderExecuted(orderId, block.chainid, order.amountIn, amountOut);
    }
    
    /**
     * @notice Initiates cross-chain execution of an order
     * @param orderId The ID of the order to execute
     */
    function _initiateCrossChainExecution(uint256 orderId) internal {
        OrderBook.Order memory order = orderBook.getOrder(orderId);
        
        // Find the best chain to execute on
        uint256 targetChain = _findBestExecutionChain(order);
        
        // If no suitable chain found, return
        if (targetChain == 0 || targetChain == block.chainid) return;
        
        // Check if tokens are compatible with bridging
        bool canBridgeTokens = tokenChecker.isTokenBridgeable(order.tokenIn);
        
        if (canBridgeTokens) {
            // Bridge tokens approach
            _bridgeAndExecute(orderId, targetChain);
        } else {
            // Message-only approach
            _sendExecutionMessage(orderId, targetChain);
        }
    }
    
    /**
     * @notice Finds the best chain to execute an order on
     * @param order The order to find the best chain for
     * @return The chain ID of the best chain to execute on
     */
    function _findBestExecutionChain(OrderBook.Order memory order) internal view returns (uint256) {
        // For now, just return the first target chain that isn't the current chain
        // In a more sophisticated implementation, we would compare prices across chains
        for (uint256 i = 0; i < order.targetChains.length; i++) {
            if (order.targetChains[i] != block.chainid) {
                return order.targetChains[i];
            }
        }
        
        // If no other chain is found, return the current chain
        return block.chainid;
    }
    
    /**
     * @notice Bridges tokens to another chain and initiates execution there
     * @param orderId The ID of the order to execute
     * @param targetChain The chain ID to bridge to
     */
    function _bridgeAndExecute(uint256 orderId, uint256 targetChain) internal {
        OrderBook.Order memory order = orderBook.getOrder(orderId);
        
        // Mark order as pending cross-chain execution
        orderBook.setPendingCrossChain(orderId, targetChain);
        
        // Approve token spending
        IERC20(order.tokenIn).approve(address(bridge), order.amountIn);
        
        // Bridge tokens to target chain
        bytes32 msgHash = bridge.sendERC20(
            order.tokenIn,
            address(this),  // Send to this contract on the target chain
            order.amountIn,
            targetChain
        );
        
        emit CrossChainExecutionInitiated(orderId, targetChain, msgHash);
    }
    
    /**
     * @notice Sends a message to another chain to execute an order
     * @param orderId The ID of the order to execute
     * @param targetChain The chain ID to send the message to
     */
    function _sendExecutionMessage(uint256 orderId, uint256 targetChain) internal {
        // This would use a cross-chain messenger to send the execution message
        // For now, we'll just emit an event as a placeholder
        bytes32 msgHash = keccak256(abi.encode(ORDER_EXECUTION_MESSAGE_TYPE, orderId, block.chainid));
        
        emit CrossChainExecutionInitiated(orderId, targetChain, msgHash);
    }
    
    /**
     * @notice Performs a swap using the Uniswap v4 pool manager
     * @param tokenIn The token to sell
     * @param tokenOut The token to buy
     * @param amountIn The amount of tokenIn to sell
     * @param minAmountOut The minimum amount of tokenOut to receive
     * @return amountOut The amount of tokenOut received
     */
    function _performSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal pure returns (uint256 amountOut) {
        // This is a simplified implementation
        // In a real implementation, we would use the Uniswap v4 pool manager to perform the swap
        
        // For now, we'll just return the minimum amount out as a placeholder
        return minAmountOut;
    }
}