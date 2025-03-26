// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISemver} from "src/interfaces/ISemver.sol";

/**
 * @title ISuperchainTokenBridge
 * @notice Interface for the Superchain token bridge
 */
interface ISuperchainTokenBridge is ISemver {
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
    ) external returns (bytes32 msgHash_);

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
    ) external;

    /**
     * @notice Constructor function
     */
    function __constructor__() external;
    
    /**
     * @notice Emitted when ERC20 tokens are sent to another chain
     * @param token The token that was sent
     * @param from The sender address
     * @param to The recipient address on the target chain
     * @param amount The amount of tokens sent
     * @param destination The target chain ID
     */
    event SendERC20(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 destination
    );

    /**
     * @notice Emitted when ERC20 tokens are relayed from another chain
     * @param token The token that was relayed
     * @param from The sender address on the source chain
     * @param to The recipient address on this chain
     * @param amount The amount of tokens relayed
     * @param source The source chain ID
     */
    event RelayERC20(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 source
    );
}