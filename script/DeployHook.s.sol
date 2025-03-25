// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {CrossChainLimitOrderHook} from "../src/CrossChainLimitOrderHook.sol";
import {OrderBook} from "../src/OrderBook.sol";
import {TokenCompatibilityChecker} from "../src/TokenCompatibilityChecker.sol";
import {CrossChainLimitOrderHookFactory} from "../src/CrossChainLimitOrderHookFactory.sol";

/**
 * @title DeployHook
 * @notice Script to deploy the CrossChainLimitOrderHook and its dependencies
 */
contract DeployHook is Script {
    // Addresses of deployed contracts
    address public hook;
    address public orderBook;
    address public tokenChecker;
    
    // Pool manager address (different per network)
    address public constant POOL_MANAGER_GOERLI = 0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b;
    address public constant POOL_MANAGER_SEPOLIA = 0x64255ed21366DB43d89736EE48928b890A84E2Cb;
    address public constant POOL_MANAGER_ANVIL = 0x0227f2B71F28E1aa1C4D39181A02aF3DEE6CF470; // Local Anvil instance
    
    // Cross-chain infrastructure addresses (different per network)
    address public constant CROSS_L2_INBOX_GOERLI = 0x0000000000000000000000000000000000000000; // Replace with actual address
    address public constant CROSS_L2_INBOX_SEPOLIA = 0x0000000000000000000000000000000000000000; // Replace with actual address
    address public constant CROSS_L2_INBOX_ANVIL = 0x0000000000000000000000000000000000000000; // Mock address for local testing
    address public constant SUPERCHAIN_TOKEN_BRIDGE_GOERLI = 0x0000000000000000000000000000000000000000; // Replace with actual address
    address public constant SUPERCHAIN_TOKEN_BRIDGE_SEPOLIA = 0x0000000000000000000000000000000000000000; // Replace with actual address
    address public constant SUPERCHAIN_TOKEN_BRIDGE_ANVIL = 0x0000000000000000000000000000000000000000; // Mock address for local testing
    
    function run() external {
        // Get the private key from the command-line argument
        uint256 deployerPrivateKey;
        
        try vm.envUint("PRIVATE_KEY") returns (uint256 pk) {
            deployerPrivateKey = pk;
        } catch {
            // If environment variable is not set, use the default Anvil private key
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the addresses based on the current chain
        address poolManagerAddress;
        address inboxAddress;
        address bridgeAddress;
        
        console.log("Chain ID:", block.chainid);
        
        if (block.chainid == 5) {
            // Goerli
            poolManagerAddress = POOL_MANAGER_GOERLI;
            inboxAddress = CROSS_L2_INBOX_GOERLI;
            bridgeAddress = SUPERCHAIN_TOKEN_BRIDGE_GOERLI;
        } else if (block.chainid == 11155111) {
            // Sepolia
            poolManagerAddress = POOL_MANAGER_SEPOLIA;
            inboxAddress = CROSS_L2_INBOX_SEPOLIA;
            bridgeAddress = SUPERCHAIN_TOKEN_BRIDGE_SEPOLIA;
        } else if (block.chainid == 31337 || block.chainid == 10) {
            // Local Anvil instance (chainid 31337 or 10)
            poolManagerAddress = POOL_MANAGER_ANVIL;
            inboxAddress = CROSS_L2_INBOX_ANVIL;
            bridgeAddress = SUPERCHAIN_TOKEN_BRIDGE_ANVIL;
        } else {
            revert("Unsupported network");
        }
        
        // Deploy the hook and its dependencies
        CrossChainLimitOrderHookFactory factory = new CrossChainLimitOrderHookFactory();
        (
            CrossChainLimitOrderHook hookContract,
            OrderBook orderBookContract,
            TokenCompatibilityChecker tokenCheckerContract
        ) = factory.deploy(
            IPoolManager(poolManagerAddress),
            inboxAddress,
            bridgeAddress
        );
        
        // Store the addresses
        hook = address(hookContract);
        orderBook = address(orderBookContract);
        tokenChecker = address(tokenCheckerContract);
        
        // Stop broadcasting transactions
        vm.stopBroadcast();
        
        // Log the deployed addresses
        console.log("CrossChainLimitOrderHook deployed at:", hook);
        console.log("OrderBook deployed at:", orderBook);
        console.log("TokenCompatibilityChecker deployed at:", tokenChecker);
    }
}