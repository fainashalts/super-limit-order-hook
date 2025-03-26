// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {CrossChainLimitOrderHook} from "./CrossChainLimitOrderHook.sol";
import {OrderBook} from "./OrderBook.sol";
import {TokenCompatibilityChecker} from "./TokenCompatibilityChecker.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

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
        // Deploy OrderBook
        orderBook = new OrderBook();
        
        // Calculate hook address with correct flags
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        
        // Find hook address with correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(CrossChainLimitOrderHook).creationCode,
            abi.encode(
                poolManager,
                address(orderBook),
                address(0), // tokenChecker will be deployed later
                inboxAddress,
                bridgeAddress
            )
        );

        // Deploy hook with found salt
        hook = new CrossChainLimitOrderHook{salt: salt}(
            poolManager,
            address(orderBook),
            address(0), // tokenChecker will be deployed later
            inboxAddress,
            bridgeAddress
        );

        require(address(hook) == hookAddress, "Hook address mismatch");
        
        // Set hook in OrderBook
        orderBook.setHook(address(hook));
        
        // Deploy TokenCompatibilityChecker from hook's address
        tokenChecker = new TokenCompatibilityChecker();
        
        emit HookDeployed(
            address(hook),
            address(orderBook),
            address(tokenChecker)
        );
        
        return (hook, orderBook, tokenChecker);
    }
}