// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {CrossChainLimitOrderHook} from "./CrossChainLimitOrderHook.sol";
import {OrderBook} from "./OrderBook.sol";
import {TokenCompatibilityChecker} from "./TokenCompatibilityChecker.sol";
import {HookMiner} from "../lib/v4-periphery/src/utils/HookMiner.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

/**
 * @title CrossChainLimitOrderHookFactory
 * @notice Factory contract for deploying the CrossChainLimitOrderHook and its dependencies
 */
contract CrossChainLimitOrderHookFactory {
    // ============ Events ============
    event HookDeployed(
        address indexed hook,
        address indexed orderBook,
        address indexed tokenChecker
    );
    
    /**
     * @notice Deploys the CrossChainLimitOrderHook and its dependencies
     * @param poolManager The Uniswap v4 pool manager
     * @param inboxAddress The address of the cross-chain inbox
     * @param bridgeAddress The address of the superchain token bridge
     * @return hook The deployed hook
     * @return orderBook The deployed order book
     * @return tokenChecker The deployed token compatibility checker
     */
    function deploy(
        IPoolManager poolManager,
        address inboxAddress,
        address bridgeAddress
    ) external returns (
        CrossChainLimitOrderHook hook,
        OrderBook orderBook,
        TokenCompatibilityChecker tokenChecker
    ) {
        // Deploy the dependencies first
        orderBook = new OrderBook();
        tokenChecker = new TokenCompatibilityChecker();
        
        // Calculate the flags for the hook (beforeSwap and afterSwap)
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        
        // Get the creation code and constructor arguments
        bytes memory creationCode = type(CrossChainLimitOrderHook).creationCode;
        bytes memory constructorArgs = abi.encode(
            poolManager,
            address(orderBook),
            address(tokenChecker),
            inboxAddress,
            bridgeAddress
        );
        
        // Find a valid salt for the hook address
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            creationCode,
            constructorArgs
        );
        
        // Deploy the hook with the calculated salt
        hook = new CrossChainLimitOrderHook{salt: salt}(
            poolManager,
            address(orderBook),
            address(tokenChecker),
            inboxAddress,
            bridgeAddress
        );
        
        // Verify that the hook was deployed to the expected address
        require(address(hook) == hookAddress, "Hook deployed to unexpected address");
        
        // Set the hook address in the OrderBook
        orderBook.setHook(address(hook));
        
        emit HookDeployed(
            address(hook),
            address(orderBook),
            address(tokenChecker)
        );
        
        return (hook, orderBook, tokenChecker);
    }
}