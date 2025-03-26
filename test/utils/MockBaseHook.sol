// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseHook} from "../../lib/v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

/**
 * @title MockBaseHook
 * @notice A modified version of BaseHook that skips address validation for testing
 */
abstract contract MockBaseHook is BaseHook {
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    /**
     * @notice Override the validateHookAddress method to skip validation in tests
     */
    function validateHookAddress(BaseHook _this) internal pure override {}
} 