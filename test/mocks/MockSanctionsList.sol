// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title MockSanctionsList
 * @notice Mock contract for testing sanctions list functionality
 */
contract MockSanctionsList {
    mapping(address => bool) private _sanctioned;

    function setSanctioned(address addr, bool sanctioned) external {
        _sanctioned[addr] = sanctioned;
    }

    function isSanctioned(address addr) external view returns (bool) {
        return _sanctioned[addr];
    }
}
