// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ICrossL2Inbox} from "../../interfaces/ICrossL2Inbox.sol";

/**
 * @title MockCrossL2Inbox
 * @notice Mock implementation of ICrossL2Inbox for testing
 */
contract MockCrossL2Inbox is ICrossL2Inbox {
    // Current message being processed
    Identifier private currentId;
    
    // Mapping to track validated messages
    mapping(bytes32 => bool) public validatedMessages;
    
    // Interop start block
    uint256 private _interopStart;
    
    /**
     * @notice Sets the current message identifier for testing
     * @param id The identifier to set
     */
    function setCurrentIdentifier(Identifier calldata id) external {
        currentId = id;
    }
    
    /**
     * @notice Gets the version of the inbox
     * @return The version string
     */
    function version() external pure override returns (string memory) {
        return "1.0.0";
    }
    
    /**
     * @notice Gets the interop start block number
     * @return interopStart_ The block number when interop started
     */
    function interopStart() external view override returns (uint256 interopStart_) {
        return _interopStart;
    }
    
    /**
     * @notice Gets the origin address of the current message
     * @return The origin address
     */
    function origin() external view override returns (address) {
        return currentId.origin;
    }
    
    /**
     * @notice Gets the block number of the current message
     * @return The block number
     */
    function blockNumber() external view override returns (uint256) {
        return currentId.blockNumber;
    }
    
    /**
     * @notice Gets the log index of the current message
     * @return The log index
     */
    function logIndex() external view override returns (uint256) {
        return currentId.logIndex;
    }
    
    /**
     * @notice Gets the timestamp of the current message
     * @return The timestamp
     */
    function timestamp() external view override returns (uint256) {
        return currentId.timestamp;
    }
    
    /**
     * @notice Gets the chain ID of the current message
     * @return The chain ID
     */
    function chainId() external view override returns (uint256) {
        return currentId.chainId;
    }
    
    /**
     * @notice Sets the interop start block number
     */
    function setInteropStart() external override {
        _interopStart = block.number;
    }
    
    /**
     * @notice Validates a cross-chain message
     * @param _id The identifier of the message
     * @param _msgHash The hash of the message
     */
    function validateMessage(
        Identifier calldata _id,
        bytes32 _msgHash
    ) external override {
        // Mark message as validated
        validatedMessages[_msgHash] = true;
        
        // Set current identifier
        currentId = _id;
        
        // Emit event
        emit ExecutingMessage(_msgHash, _id);
    }
}