// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ISemver
 * @notice Interface for semantic versioning
 */
interface ISemver {
    /**
     * @notice Gets the version string
     * @return The version string
     */
    function version() external view returns (string memory);
} 