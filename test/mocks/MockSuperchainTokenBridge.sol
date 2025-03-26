// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISuperchainTokenBridge} from "../../src/interfaces/ISuperchainTokenBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockSuperchainTokenBridge
 * @notice Mock implementation of ISuperchainTokenBridge for testing
 */
contract MockSuperchainTokenBridge is ISuperchainTokenBridge {
    // Mapping to track bridged tokens
    mapping(bytes32 => bool) public bridgedTokens;
    
    /**
     * @notice Gets the version of the bridge
     * @return The version string
     */
    function version() external pure override returns (string memory) {
        return "1.0.0";
    }
    
    /**
     * @notice Sends ERC20 tokens to another chain
     * @param _token The token to send
     * @param _to The recipient address on the target chain
     * @param _amount The amount of tokens to send
     * @param _chainId The target chain ID
     * @return msgHash_ The hash of the message
     */
    function sendERC20(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _chainId
    ) external override returns (bytes32 msgHash_) {
        // Generate message hash
        msgHash_ = keccak256(abi.encode(_token, _to, _amount, _chainId, block.timestamp));
        
        // Mark as bridged
        bridgedTokens[msgHash_] = true;
        
        // Transfer tokens from sender to this contract (simulating bridging)
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        
        // Emit event
        emit SendERC20(_token, msg.sender, _to, _amount, _chainId);
        
        return msgHash_;
    }
    
    /**
     * @notice Relays ERC20 tokens from another chain
     * @param _token The token to relay
     * @param _from The sender address on the source chain
     * @param _to The recipient address on this chain
     * @param _amount The amount of tokens to relay
     */
    function relayERC20(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external override {
        // In a real implementation, this would mint or transfer tokens
        // For testing, we'll just emit the event
        
        emit RelayERC20(_token, _from, _to, _amount, 0);
    }
    
    /**
     * @notice Constructor function
     */
    function __constructor__() external override {
        // No-op for testing
    }
}