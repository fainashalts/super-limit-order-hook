// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title OrderBook
 * @notice Manages limit orders for the CrossChainLimitOrderHook
 * @dev Stores and manages the lifecycle of limit orders
 */
contract OrderBook {
    // ============ Enums ============
    enum OrderStatus {
        NONE,
        ACTIVE,
        EXECUTED,
        CANCELLED,
        EXPIRED,
        PENDING_CROSS_CHAIN
    }
    
    // ============ Structs ============
    struct Order {
        address owner;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 expiry;
        uint256[] targetChains;
        OrderStatus status;
        uint256 pendingChain; // If status is PENDING_CROSS_CHAIN, this is the chain ID
    }
    
    // ============ State Variables ============
    address public hook;
    uint256 public nextOrderId = 1;
    
    // Order storage
    mapping(uint256 => Order) private orders;
    
    // Indexes for efficient querying
    mapping(address => mapping(address => uint256[])) private tokenPairOrders; // tokenIn => tokenOut => orderIds
    
    // ============ Events ============
    event OrderCreated(uint256 indexed orderId, address indexed owner);
    event OrderStatusUpdated(uint256 indexed orderId, OrderStatus status);
    
    // ============ Errors ============
    error Unauthorized();
    error InvalidOrder();
    error OrderNotFound();
    
    // ============ Constructor ============
    constructor() {
        // hook will be set later
    }
    
    // ============ Modifiers ============
    modifier onlyHook() {
        if (msg.sender != hook) revert Unauthorized();
        _;
    }
    
    // ============ External Functions ============
    
    /**
     * @notice Sets the hook address
     * @param _hook The address of the hook
     */
    function setHook(address _hook) external {
        if (hook != address(0)) revert Unauthorized();
        hook = _hook;
    }
    
    /**
     * @notice Creates a new limit order
     * @param owner The owner of the order
     * @param tokenIn The token to sell
     * @param tokenOut The token to buy
     * @param amountIn The amount of tokenIn to sell
     * @param minAmountOut The minimum amount of tokenOut to receive
     * @param expiry The timestamp when the order expires
     * @param targetChains Array of chain IDs to monitor for execution
     * @return orderId The ID of the created order
     */
    function createOrder(
        address owner,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 expiry,
        uint256[] calldata targetChains
    ) external onlyHook returns (uint256 orderId) {
        orderId = nextOrderId++;
        
        orders[orderId] = Order({
            owner: owner,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            expiry: expiry,
            targetChains: targetChains,
            status: OrderStatus.ACTIVE,
            pendingChain: 0
        });
        
        // Add to token pair index
        tokenPairOrders[tokenIn][tokenOut].push(orderId);
        
        emit OrderCreated(orderId, owner);
        emit OrderStatusUpdated(orderId, OrderStatus.ACTIVE);
        
        return orderId;
    }
    
    /**
     * @notice Marks an order as executed
     * @param orderId The ID of the order
     */
    function executeOrder(uint256 orderId) external onlyHook {
        Order storage order = orders[orderId];
        if (order.status != OrderStatus.ACTIVE && order.status != OrderStatus.PENDING_CROSS_CHAIN) {
            revert InvalidOrder();
        }
        
        order.status = OrderStatus.EXECUTED;
        emit OrderStatusUpdated(orderId, OrderStatus.EXECUTED);
    }
    
    /**
     * @notice Marks an order as cancelled
     * @param orderId The ID of the order
     */
    function cancelOrder(uint256 orderId) external onlyHook {
        Order storage order = orders[orderId];
        if (order.status != OrderStatus.ACTIVE && order.status != OrderStatus.PENDING_CROSS_CHAIN) {
            revert InvalidOrder();
        }
        
        order.status = OrderStatus.CANCELLED;
        emit OrderStatusUpdated(orderId, OrderStatus.CANCELLED);
    }
    
    /**
     * @notice Marks an order as expired
     * @param orderId The ID of the order
     */
    function expireOrder(uint256 orderId) external onlyHook {
        Order storage order = orders[orderId];
        if (order.status != OrderStatus.ACTIVE) {
            revert InvalidOrder();
        }
        
        order.status = OrderStatus.EXPIRED;
        emit OrderStatusUpdated(orderId, OrderStatus.EXPIRED);
    }
    
    /**
     * @notice Marks an order as pending cross-chain execution
     * @param orderId The ID of the order
     * @param targetChain The chain ID where the order will be executed
     */
    function setPendingCrossChain(uint256 orderId, uint256 targetChain) external onlyHook {
        Order storage order = orders[orderId];
        if (order.status != OrderStatus.ACTIVE) {
            revert InvalidOrder();
        }
        
        order.status = OrderStatus.PENDING_CROSS_CHAIN;
        order.pendingChain = targetChain;
        emit OrderStatusUpdated(orderId, OrderStatus.PENDING_CROSS_CHAIN);
    }
    
    /**
     * @notice Gets the details of an order
     * @param orderId The ID of the order
     * @return The order details
     */
    function getOrder(uint256 orderId) external view returns (Order memory) {
        Order memory order = orders[orderId];
        if (order.owner == address(0)) {
            revert OrderNotFound();
        }
        return order;
    }
    
    /**
     * @notice Gets the status of an order
     * @param orderId The ID of the order
     * @return The status of the order
     */
    function getOrderStatus(uint256 orderId) external view returns (OrderStatus) {
        return orders[orderId].status;
    }
    
    /**
     * @notice Gets all eligible orders for a token pair
     * @param tokenIn The input token
     * @param tokenOut The output token
     * @return Array of order IDs
     */
    function getEligibleOrders(address tokenIn, address tokenOut) external view returns (uint256[] memory) {
        return tokenPairOrders[tokenIn][tokenOut];
    }
}