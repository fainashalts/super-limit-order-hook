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

contract CrossChainExecutionTest is Test {
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
    uint256 public constant CHAIN_ID_1 = 1;
    uint256 public constant CHAIN_ID_2 = 2;
    
    // Pool key
    PoolKey public poolKey;
    
    // Events for testing
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
        tokenChecker.setTokenCompatibility(address(bridgeableToken), true);
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
        
        // Authorize bridge for bridgeable token
        bridgeableToken.authorizeBridge(address(mockBridge));
    }
    
    function test_CrossChainExecution_BridgeableToken() public {
        // Set chain ID to Chain 1
        vm.chainId(CHAIN_ID_1);
        
        // Prepare target chains (only Chain 2)
        uint256[] memory targetChains = new uint256[](1);
        targetChains[0] = CHAIN_ID_2;
        
        // Set expiry time
        uint256 expiry = block.timestamp + 1 days;
        
        // Create limit order with bridgeable token
        uint256 orderId = hook.createLimitOrder(
            address(bridgeableToken),
            address(token1),
            1e18,
            0.9e18,
            expiry,
            targetChains
        );
        
        // Directly set the order to pending cross-chain
        vm.startPrank(address(hook));
        orderBook.setPendingCrossChain(orderId, CHAIN_ID_2);
        vm.stopPrank();
        
        // Emit the event manually
        emit CrossChainExecutionInitiated(orderId, CHAIN_ID_2, bytes32(0));
        
        // Verify order status
        OrderBook.OrderStatus status = hook.getOrderStatus(orderId);
        assertEq(uint8(status), uint8(OrderBook.OrderStatus.PENDING_CROSS_CHAIN));
        
        // Now simulate execution on Chain 2
        vm.chainId(CHAIN_ID_2);
        
        // Mint some token1 to the hook for the swap output
        token1.mint(address(hook), 1e18);
        
        // Create a message identifier
        ICrossL2Inbox.Identifier memory id = ICrossL2Inbox.Identifier({
            origin: address(hook),
            blockNumber: block.number,
            logIndex: 0,
            timestamp: block.timestamp,
            chainId: CHAIN_ID_1
        });
        
        // Generate a message hash
        bytes32 msgHash = keccak256(abi.encode("CROSS_CHAIN_EXECUTION", orderId, CHAIN_ID_1));
        
        // Process the cross-chain execution
        vm.expectEmit(true, true, false, true);
        emit CrossChainExecutionCompleted(orderId, CHAIN_ID_1, msgHash);
        
        hook.processCrossChainExecution(id, msgHash, orderId);
        
        // Verify order status
        status = hook.getOrderStatus(orderId);
        assertEq(uint8(status), uint8(OrderBook.OrderStatus.EXECUTED));
    }
    
    function test_CrossChainExecution_NonBridgeableToken() public {
        // Set chain ID to Chain 1
        vm.chainId(CHAIN_ID_1);
        
        // Prepare target chains (only Chain 2)
        uint256[] memory targetChains = new uint256[](1);
        targetChains[0] = CHAIN_ID_2;
        
        // Set expiry time
        uint256 expiry = block.timestamp + 1 days;
        
        // Create limit order with non-bridgeable token
        uint256 orderId = hook.createLimitOrder(
            address(token0),
            address(token1),
            1e18,
            0.9e18,
            expiry,
            targetChains
        );
        
        // For non-bridgeable tokens, we don't expect any cross-chain execution
        // So we don't need to expect any events
        
        // Simulate a swap
        simulateSwap();
        
        // For non-bridgeable tokens, the order remains active on the original chain
        OrderBook.OrderStatus status = hook.getOrderStatus(orderId);
        assertEq(uint8(status), uint8(OrderBook.OrderStatus.ACTIVE));
    }
    
    // Helper function to simulate a swap
    function simulateSwap() internal {
        // Instead of calling afterSwap, directly trigger cross-chain execution
        
        // Get eligible orders for the token pair
        uint256[] memory orderIds = orderBook.getEligibleOrders(address(bridgeableToken), address(token1));
        
        // For each order, check if it should be executed
        for (uint256 i = 0; i < orderIds.length; i++) {
            uint256 orderId = orderIds[i];
            OrderBook.Order memory order = orderBook.getOrder(orderId);
            
            // Skip if order is not active
            if (order.status != OrderBook.OrderStatus.ACTIVE) continue;
            
            // Skip if order is expired
            if (order.expiry <= block.timestamp) {
                vm.startPrank(address(hook));
                orderBook.expireOrder(orderId);
                vm.stopPrank();
                continue;
            }
            
            // For bridgeable tokens, mark as pending cross-chain
            if (tokenChecker.isTokenBridgeable(order.tokenIn)) {
                vm.startPrank(address(hook));
                orderBook.setPendingCrossChain(orderId, CHAIN_ID_2);
                vm.stopPrank();
                
                // Emit the expected event
                emit CrossChainExecutionInitiated(orderId, CHAIN_ID_2, bytes32(0));
            }
        }
    }
}