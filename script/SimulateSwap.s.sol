// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TestCrossChainLimitOrderHook} from "../test/mocks/TestCrossChainLimitOrderHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {OrderBook} from "../src/OrderBook.sol";
import {TokenCompatibilityChecker} from "../src/TokenCompatibilityChecker.sol";

contract SimulateSwap is Script {
    function run() public {
        // Get the private key from the command-line argument
        uint256 deployerPrivateKey;
        
        try vm.envUint("PRIVATE_KEY") returns (uint256 pk) {
            deployerPrivateKey = pk;
        } catch {
            // If environment variable is not set, use the default Anvil private key
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        
        // Get the pool manager address from the environment or use the default
        address poolManagerAddress;
        try vm.envAddress("POOL_MANAGER_ADDRESS") returns (address addr) {
            poolManagerAddress = addr;
        } catch {
            // Use a default address for the pool manager
            poolManagerAddress = 0x0227f2B71F28E1aa1C4D39181A02aF3DEE6CF470;
        }
        
        // Get the token addresses from the environment or use defaults
        address token0Address;
        address token1Address;
        
        try vm.envAddress("TOKEN0_ADDRESS") returns (address addr) {
            token0Address = addr;
        } catch {
            // Use a default address for token0
            token0Address = 0x1111111111111111111111111111111111111111;
        }
        
        try vm.envAddress("TOKEN1_ADDRESS") returns (address addr) {
            token1Address = addr;
        } catch {
            // Use a default address for token1
            token1Address = 0x2222222222222222222222222222222222222222;
        }
        
        console.log("Using pool manager address:", poolManagerAddress);
        console.log("Using token0 address:", token0Address);
        console.log("Using token1 address:", token1Address);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the dependencies
        OrderBook orderBook = new OrderBook();
        TokenCompatibilityChecker tokenChecker = new TokenCompatibilityChecker();
        
        // Deploy the test hook
        TestCrossChainLimitOrderHook hook = new TestCrossChainLimitOrderHook(
            IPoolManager(poolManagerAddress),
            address(orderBook),
            address(tokenChecker)
        );
        
        // Set the hook address in the OrderBook
        orderBook.setHook(address(hook));
        
        console.log("Deployed test hook at:", address(hook));
        console.log("Deployed order book at:", address(orderBook));
        console.log("Deployed token checker at:", address(tokenChecker));
        
        // Create a test limit order
        address owner = msg.sender;
        address tokenIn = token0Address;
        address tokenOut = token1Address;
        uint256 amountIn = 1e18;
        uint256 minAmountOut = 9e17; // 90% of 1e18
        uint256 expiry = block.timestamp + 1 days;
        
        console.log("Creating test limit order...");
        uint256 orderId = hook.createTestOrder(
            owner,
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            expiry
        );
        console.log("Created order with ID:", orderId);
        
        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0Address),
            currency1: Currency.wrap(token1Address),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        // Create swap parameters
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: 1e18,
            sqrtPriceLimitX96: 4295128740
        });
        
        // Create a fake delta with a good price
        BalanceDelta delta = toBalanceDelta(
            -int128(1e18),  // amount0 (negative means outgoing)
            int128(1e18)  // amount1 (positive means incoming) - 1:1 price
        );
        
        console.log("Simulating swap...");
        
        // Call afterSwap directly for testing
        try hook.afterSwap(msg.sender, poolKey, params, delta, "") returns (bytes4 selector, int128 deltaAmount) {
            console.log("Swap simulation successful!");
            console.log("Selector:", uint32(selector));
            console.log("Delta amount:", uint256(uint128(deltaAmount)));
        } catch Error(string memory reason) {
            console.log("Swap simulation failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Swap simulation failed with low-level error");
        }
        
        vm.stopBroadcast();
    }
}