// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC7802} from "./interfaces/IERC7802.sol";
import {ISuperchainTokenBridge} from "./interfaces/ISuperchainTokenBridge.sol";
import {PredeployAddresses} from "./libraries/PredeployAddresses.sol";

/**
 * @title TokenCompatibilityChecker
 * @notice Checks if tokens are compatible with the Superchain bridge
 * @dev Determines if tokens can be bridged directly using the Superchain bridge
 */
contract TokenCompatibilityChecker {
    // ============ State Variables ============
    address public immutable hook;
    ISuperchainTokenBridge public immutable bridge;
    
    // Cache of token compatibility
    mapping(address => bool) private compatibilityCache;
    
    // ============ Events ============
    event TokenCompatibilityChecked(address indexed token, bool isCompatible);
    
    // ============ Errors ============
    error Unauthorized();
    
    // ============ Constructor ============
    constructor() {
        hook = msg.sender;
        bridge = ISuperchainTokenBridge(PredeployAddresses.SUPERCHAIN_TOKEN_BRIDGE);
    }
    
    // ============ Modifiers ============
    modifier onlyHook() {
        if (msg.sender != hook) revert Unauthorized();
        _;
    }
    
    // ============ External Functions ============
    
    /**
     * @notice Checks if a token can be bridged directly
     * @param token The token address to check
     * @return True if the token can be bridged directly
     */
    function isTokenBridgeable(address token) external returns (bool) {
        // Check cache first
        if (compatibilityCache[token]) {
            return true;
        }
        
        // Check if token is a SuperchainERC20 token (predefined list)
        if (_isSuperchainERC20(token)) {
            compatibilityCache[token] = true;
            emit TokenCompatibilityChecked(token, true);
            return true;
        }
        
        // Check if token implements ERC7802
        if (_isERC7802Compatible(token)) {
            compatibilityCache[token] = true;
            emit TokenCompatibilityChecked(token, true);
            return true;
        }
        
        emit TokenCompatibilityChecked(token, false);
        return false;
    }
    
    /**
     * @notice Manually sets the compatibility of a token
     * @param token The token address
     * @param isCompatible Whether the token is compatible
     */
    function setTokenCompatibility(address token, bool isCompatible) external onlyHook {
        compatibilityCache[token] = isCompatible;
        emit TokenCompatibilityChecked(token, isCompatible);
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Checks if a token is a SuperchainERC20 token
     * @param token The token address to check
     * @return True if the token is a SuperchainERC20 token
     */
    function _isSuperchainERC20(address token) internal pure returns (bool) {
        // In a real implementation, this would check against a list of known SuperchainERC20 tokens
        // For now, we'll just return false as a placeholder
        return false;
    }
    
    /**
     * @notice Checks if a token implements ERC7802 and has granted permissions to the bridge
     * @param token The token address to check
     * @return True if the token implements ERC7802 and has granted permissions
     */
    function _isERC7802Compatible(address token) internal view returns (bool) {
        // Check if the token implements ERC7802
        try IERC165(token).supportsInterface(type(IERC7802).interfaceId) returns (bool supported) {
            if (!supported) {
                return false;
            }
            
            // In a real implementation, we would also check if the token has granted
            // mint/burn permissions to the bridge
            // For now, we'll assume that if it implements ERC7802, it's compatible
            return true;
        } catch {
            return false;
        }
    }
}