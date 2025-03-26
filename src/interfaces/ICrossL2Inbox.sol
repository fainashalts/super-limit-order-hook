// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISemver} from "src/interfaces/ISemver.sol";

/**
 * @title ICrossL2Inbox
 * @notice Interface for cross-layer-2 message inbox
 */
interface ICrossL2Inbox is ISemver {
    /**
     * @notice Identifier struct for cross-chain messages
     */
    struct Identifier {
        address origin;
        uint256 blockNumber;
        uint256 logIndex;
        uint256 timestamp;
        uint256 chainId;
    }
    
    /**
     * @notice Gets the version of the inbox
     * @return The version string
     */
    function version() external view returns (string memory);
    
    /**
     * @notice Gets the interop start block number
     * @return interopStart_ The block number when interop started
     */
    function interopStart() external view returns (uint256 interopStart_);
    
    /**
     * @notice Gets the origin address of the current message
     * @return The origin address
     */
    function origin() external view returns (address);
    
    /**
     * @notice Gets the block number of the current message
     * @return The block number
     */
    function blockNumber() external view returns (uint256);
    
    /**
     * @notice Gets the log index of the current message
     * @return The log index
     */
    function logIndex() external view returns (uint256);
    
    /**
     * @notice Gets the timestamp of the current message
     * @return The timestamp
     */
    function timestamp() external view returns (uint256);
    
    /**
     * @notice Gets the chain ID of the current message
     * @return The chain ID
     */
    function chainId() external view returns (uint256);
    
    /**
     * @notice Sets the interop start block number
     */
    function setInteropStart() external;
    
    /**
     * @notice Validates a cross-chain message
     * @param _id The identifier of the message
     * @param _msgHash The hash of the message
     */
    function validateMessage(Identifier calldata _id, bytes32 _msgHash) external;
    
    /**
     * @notice Emitted when a message is executed
     * @param msgHash The hash of the message
     * @param id The identifier of the message
     */
    event ExecutingMessage(bytes32 indexed msgHash, Identifier id);
}