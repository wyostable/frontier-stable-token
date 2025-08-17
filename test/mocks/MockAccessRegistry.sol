// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title MockAccessRegistry
 * @notice Mock access registry for testing FrontierERC20F access control
 */
contract MockAccessRegistry {
    mapping(address => bool) private _hasAccess;

    function setAccess(address user, bool access) external {
        _hasAccess[user] = access;
    }

    function hasAccess(address account, address /*target*/, bytes calldata /*data*/) external view returns (bool) {
        return _hasAccess[account];
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        // IAccessRegistry interface ID: 0xeefb7e9a
        return interfaceId == 0xeefb7e9a || interfaceId == 0x01ffc9a7; // ERC165
    }
}
