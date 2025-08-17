// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.22;

interface IFrontierERC20F {
    // Events
    event MintedToFrozen(address indexed caller, address indexed to, uint256 amount);
    event TransferredToFrozen(address indexed caller, address indexed to, uint256 amount);

    /**
     * @notice Checks if an account has access.
     * @param account The address of the account to check.
     * @return bool True if the account has access, false otherwise.
     */
    function hasAccess(address account) external view returns (bool);

    /**
     * @notice Burn hook for the adapter to call.
     * @param from The address to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function adapterBurn(address from, uint256 amount) external;

    /**
     * @notice Mint hook for the adapter to call.
     * @param to Address to which tokens will be minted
     * @param amount Amount of tokens to be minted
     */
    function adapterMint(address to, uint256 amount) external;

    /**
     * @notice Transfer hook for the adapter to call.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function adapterTransfer(address to, uint256 amount) external;
}
