// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ISemver
 * @notice Interface for semantic versioning
 */
interface ISemver {
    /**
     * @notice Gets the semantic version
     * @return The semantic version string
     */
    function version() external view returns (string memory);
} 