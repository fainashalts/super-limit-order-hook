// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC7802
 * @notice Interface for the ERC-7802 standard for cross-chain ERC20 token transfers
 */
interface IERC7802 is IERC165 {
    /**
     * @notice Mints tokens to a recipient as part of a cross-chain transfer
     * @param _to The address to mint tokens to
     * @param _amount The amount of tokens to mint
     */
    function crosschainMint(
        address _to,
        uint256 _amount
    ) external;

    /**
     * @notice Burns tokens from a sender as part of a cross-chain transfer
     * @param _from The address to burn tokens from
     * @param _amount The amount of tokens to burn
     */
    function crosschainBurn(
        address _from,
        uint256 _amount
    ) external;
    
    /**
     * @notice Emitted when tokens are minted as part of a cross-chain transfer
     * @param to The address that received the tokens
     * @param amount The amount of tokens minted
     * @param sender The address that initiated the cross-chain transfer
     */
    event CrosschainMint(
        address indexed to,
        uint256 amount,
        address indexed sender
    );

    /**
     * @notice Emitted when tokens are burned as part of a cross-chain transfer
     * @param from The address that had tokens burned
     * @param amount The amount of tokens burned
     * @param sender The address that initiated the cross-chain transfer
     */
    event CrosschainBurn(
        address indexed from,
        uint256 amount,
        address indexed sender
    );
}