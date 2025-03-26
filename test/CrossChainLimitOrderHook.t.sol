// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

import {MockCrossChainLimitOrderHook} from "./mocks/MockCrossChainLimitOrderHook.sol";
import {OrderBook} from "../src/OrderBook.sol";
import {TokenCompatibilityChecker} from "../src/TokenCompatibilityChecker.sol";
import {CrossChainLimitOrderHookFactory} from "../src/CrossChainLimitOrderHookFactory.sol";
import {ICrossL2Inbox} from "../src/interfaces/ICrossL2Inbox.sol";
import {ISuperchainTokenBridge} from "../src/interfaces/ISuperchainTokenBridge.sol";
import {IERC7802} from "../src/interfaces/IERC7802.sol";
import {MockCrossL2Inbox} from "./mocks/MockCrossL2Inbox.sol";
import {MockSuperchainTokenBridge} from "./mocks/MockSuperchainTokenBridge.sol";
import {MockERC7802Token} from "./mocks/MockERC7802Token.sol";

contract CrossChainLimitOrderHookTest is Test {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    // Test contracts
    PoolManager public poolManager;
    MockCrossChainLimitOrderHook public hook;
    OrderBook public orderBook;
    TokenCompatibilityChecker public tokenChecker;
    
    // Mock tokens
    MockERC20 public token0;
    MockERC20 public token1;
    MockERC7802Token public bridgeableToken;
    
    // Mock interop contracts
    MockCrossL2Inbox public mockInbox;
    MockSuperchainTokenBridge public mockBridge;
    
    // Test parameters
    uint24 public constant FEE = 3000;
    int24 public constant TICK_SPACING = 60;
    uint256 public constant CHAIN_ID = 1;
    uint256 public constant TARGET_CHAIN_ID = 2;
    
    // Pool key
    PoolKey public poolKey;
    
    // Events for testing
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
    
    function setUp() public {
        // Deploy mock tokens
        token0 = new MockERC20("Token0", "TKN0", 18);
        token1 = new MockERC20("Token1", "TKN1", 18);
        bridgeableToken = new MockERC7802Token("BridgeToken", "BTKN", 18);
        
        // Sort tokens by address (required by Uniswap)
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }
        
        // Deploy mock interop contracts
        mockInbox = new MockCrossL2Inbox();
        mockBridge = new MockSuperchainTokenBridge();
        
        // Deploy pool manager
        poolManager = new PoolManager(address(this));
        
        // Deploy OrderBook
        orderBook = new OrderBook();
        
        // Deploy hook with the correct address
        // Calculate the flags
        uint160 flags = Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;
        
        // Prepare the creation code and constructor args
        bytes memory creationCode = type(MockCrossChainLimitOrderHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(poolManager)),
            address(orderBook),
            address(0), // We'll set tokenChecker later
            address(mockInbox),
            address(mockBridge)
        );
        
        // Find a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this), // deployer
            flags,
            creationCode,
            constructorArgs
        );
        
        // Deploy the hook with the found salt
        hook = new MockCrossChainLimitOrderHook{salt: salt}(
            IPoolManager(address(poolManager)),
            address(orderBook),
            address(0), // We'll set tokenChecker later
            address(mockInbox),
            address(mockBridge)
        );
        
        // Verify the deployed address matches the expected address
        assertEq(address(hook), hookAddress, "Hook address mismatch");
        
        // Set the hook address in the OrderBook
        orderBook.setHook(address(hook));
        
        // Now deploy TokenCompatibilityChecker from the hook's address
        vm.startPrank(address(hook));
        tokenChecker = new TokenCompatibilityChecker();
        vm.stopPrank();
        
        // Create pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });
        
        // Initialize pool
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0);
        poolManager.initialize(poolKey, sqrtPriceX96);
        
        // Mint tokens to this contract
        token0.mint(address(this), 1000e18);
        token1.mint(address(this), 1000e18);
        bridgeableToken.mint(address(this), 1000e18);
        
        // Approve tokens for the hook
        token0.approve(address(hook), type(uint256).max);
        token1.approve(address(hook), type(uint256).max);
        bridgeableToken.approve(address(hook), type(uint256).max);
        
        // Set chain ID for testing
        vm.chainId(CHAIN_ID);
    }
    
    function test_CreateLimitOrder() public {
        // Prepare target chains
        uint256[] memory targetChains = new uint256[](2);
        targetChains[0] = CHAIN_ID;
        targetChains[1] = TARGET_CHAIN_ID;
        
        // Set expiry time
        uint256 expiry = block.timestamp + 1 days;
        
        // Create limit order
        vm.expectEmit(true, true, false, true);
        emit LimitOrderCreated(1, address(this), address(token0), address(token1), 1e18, 0.9e18, expiry, targetChains);
        
        uint256 orderId = hook.createLimitOrder(
            address(token0),
            address(token1),
            1e18,
            0.9e18,
            expiry,
            targetChains
        );
        
        // Verify order was created
        assertEq(orderId, 1);
        
        // Check order details
        OrderBook.Order memory order = hook.getOrderDetails(orderId);
        assertEq(order.owner, address(this));
        assertEq(order.tokenIn, address(token0));
        assertEq(order.tokenOut, address(token1));
        assertEq(order.amountIn, 1e18);
        assertEq(order.minAmountOut, 0.9e18);
        assertEq(order.expiry, expiry);
        assertEq(uint8(order.status), uint8(OrderBook.OrderStatus.ACTIVE));
    }
    
    function test_CancelLimitOrder() public {
        // Create a limit order first
        uint256[] memory targetChains = new uint256[](1);
        targetChains[0] = CHAIN_ID;
        
        uint256 expiry = block.timestamp + 1 days;
        uint256 orderId = hook.createLimitOrder(
            address(token0),
            address(token1),
            1e18,
            0.9e18,
            expiry,
            targetChains
        );
        
        // Cancel the order
        hook.cancelLimitOrder(orderId);
        
        // Verify order status
        OrderBook.OrderStatus status = hook.getOrderStatus(orderId);
        assertEq(uint8(status), uint8(OrderBook.OrderStatus.CANCELLED));
        
        // Verify tokens were returned
        assertEq(token0.balanceOf(address(this)), 1000e18);
    }
    
    function test_OrderExpiry() public {
        // Create a limit order with short expiry
        uint256[] memory targetChains = new uint256[](1);
        targetChains[0] = CHAIN_ID;
        
        uint256 expiry = block.timestamp + 100;
        uint256 orderId = hook.createLimitOrder(
            address(token0),
            address(token1),
            1e18,
            0.9e18,
            expiry,
            targetChains
        );
        
        // Fast forward time past expiry
        vm.warp(block.timestamp + 200);
        
        // Directly expire the order instead of simulating a swap
        vm.startPrank(address(hook));
        orderBook.expireOrder(orderId);
        vm.stopPrank();
        
        // Verify order status
        OrderBook.OrderStatus status = hook.getOrderStatus(orderId);
        assertEq(uint8(status), uint8(OrderBook.OrderStatus.EXPIRED));
    }
    
    function test_TokenCompatibilityChecker() public {
        // Check non-bridgeable token
        bool isToken0Bridgeable = tokenChecker.isTokenBridgeable(address(token0));
        assertEq(isToken0Bridgeable, false);
        
        // Check bridgeable token
        bool isBridgeableTokenBridgeable = tokenChecker.isTokenBridgeable(address(bridgeableToken));
        assertEq(isBridgeableTokenBridgeable, true);
    }
    
    // Helper function to simulate a swap
    function simulateSwap() internal {
        // This is a simplified simulation
        // In a real test, we would use the PoolManager to perform a swap
        
        // Create swap parameters
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: 1e18,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        // Create a fake delta
        BalanceDelta delta = toBalanceDelta(
            -int128(1e18),  // amount0 (negative means outgoing)
            int128(0.95e18)  // amount1 (positive means incoming)
        );
        
        // Call afterSwap directly for testing
        hook.afterSwap(address(this), poolKey, params, delta, "");
    }
}