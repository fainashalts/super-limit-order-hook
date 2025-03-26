// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PredeployAddresses
 * @notice Library containing predefined addresses for system contracts
 */
library PredeployAddresses {
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant CROSS_L2_INBOX = 0x4200000000000000000000000000000000000022;
    address internal constant L2_TO_L2_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000023;
    address internal constant SUPERCHAIN_WETH = 0x4200000000000000000000000000000000000024;
    address internal constant ETH_LIQUIDITY = 0x4200000000000000000000000000000000000025;
    address internal constant SUPERCHAIN_TOKEN_BRIDGE = 0x4200000000000000000000000000000000000028;
} 