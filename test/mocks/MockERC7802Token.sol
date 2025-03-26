// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC7802} from "../../src/interfaces/IERC7802.sol";

/**
 * @title MockERC7802Token
 * @notice Mock implementation of an ERC7802 token for testing
 */
contract MockERC7802Token is ERC20, IERC7802 {
    mapping(address => bool) public authorizedBridges;
    uint8 private immutable _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC7802).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
    
    /**
     * @notice Mints tokens to an address
     * @param to The address to mint to
     * @param amount The amount to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    /**
     * @notice Burns tokens from an address
     * @param from The address to burn from
     * @param amount The amount to burn
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
    
    /**
     * @notice Authorizes a bridge to call crosschainMint and crosschainBurn
     * @param bridge The bridge address to authorize
     */
    function authorizeBridge(address bridge) external override {
        authorizedBridges[bridge] = true;
    }
    
    /**
     * @notice Revokes authorization from a bridge
     * @param bridge The bridge address to revoke
     */
    function revokeBridge(address bridge) external {
        authorizedBridges[bridge] = false;
    }
    
    /**
     * @notice Checks if a bridge is authorized to call crosschainMint and crosschainBurn
     * @param bridge The bridge address to check
     * @return True if the bridge is authorized, false otherwise
     */
    function isBridgeAuthorized(address bridge) external view override returns (bool) {
        return authorizedBridges[bridge];
    }
    
    /**
     * @notice Mints tokens to a recipient as part of a cross-chain transfer
     * @param _to The address to mint tokens to
     * @param _amount The amount of tokens to mint
     */
    function crosschainMint(
        address _to,
        uint256 _amount
    ) external override {
        require(authorizedBridges[msg.sender], "Not authorized");
        _mint(_to, _amount);
        emit CrosschainMint(_to, _amount, msg.sender);
    }
    
    /**
     * @notice Burns tokens from a sender as part of a cross-chain transfer
     * @param _from The address to burn tokens from
     * @param _amount The amount of tokens to burn
     */
    function crosschainBurn(
        address _from,
        uint256 _amount
    ) external override {
        require(authorizedBridges[msg.sender], "Not authorized");
        _burn(_from, _amount);
        emit CrosschainBurn(_from, _amount, msg.sender);
    }
} 