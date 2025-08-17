// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.22;

import { ERC20F, LibErrors } from "./fireblocks/ERC20F.sol";
import { IFrontierERC20F } from "./interfaces/IFrontierERC20F.sol";

/**
 * @title FrontierERC20F
 * @author LayzerZero Labs (@EWCunha)
 * @notice This is a modified version of the ERC20F contract from Fireblocks, but still supports the same interface.
 */
contract FrontierERC20F is ERC20F, IFrontierERC20F {
    // @dev Additional roles for the custom minting, burning, and transferring functions of the LayerZero OFTAdapter
    bytes32 public constant ADAPTER_ROLE = keccak256("ADAPTER_ROLE"); // 0xdbeb657137b1822b3d5418bea6fd641226d964b4c3871ef23546db2622258871

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _defaultAdmin,
        address _minter,
        address _pauser
    ) external virtual override initializer {
        // @dev Initialize the ERC20F contract with the provided parameters.
        __FrontierERC20F_init(_name, _symbol, _defaultAdmin, _minter, _pauser);
    }

    function __FrontierERC20F_init(
        string calldata _name,
        string calldata _symbol,
        address defaultAdmin,
        address minter,
        address pauser
    ) internal virtual onlyInitializing {
        if (defaultAdmin == address(0) || pauser == address(0)) {
            revert LibErrors.InvalidAddress();
        }

        __UUPSUpgradeable_init();
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __Multicall_init();
        __AccessRegistrySubscription_init(address(0)); /// @dev FB's ERC20F initialize it with address(0)
        __Salvage_init();
        __ContractUri_init("");
        __Pause_init();
        __RoleAccess_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(PAUSER_ROLE, pauser);
    }

    // @dev Override the erc20 decimals to be 6.
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /**
     * @notice Checks if an account has access.
     * @param _account The address of the account to check.
     * @return bool True if the account has access, false otherwise.
     */
    function hasAccess(address _account) public view virtual returns (bool) {
        if (address(accessRegistry) != address(0)) {
            return accessRegistry.hasAccess(_account, _msgSender(), _msgData());
        }
        return true;
    }

    /**
     * @notice Burn hook for the adapter to call.
     * @param _from The address to burn tokens from.
     * @param _amount The amount of tokens to burn.
     */
    function adapterBurn(address _from, uint256 _amount) external virtual onlyRole(ADAPTER_ROLE) {
        // @dev The ERC20F implementation of burn does NOT allow us to pass a _from address, so need to define here
        if (_amount == 0) revert LibErrors.ZeroAmount();
        _requireHasAccess(_from, true);
        _burn(_from, _amount);
    }

    /**
     * @notice Mint hook for the adapter to call.
     * @param _to Address to which tokens will be minted
     * @param _amount Amount of tokens to be minted
     */
    function adapterMint(address _to, uint256 _amount) external virtual onlyRole(ADAPTER_ROLE) {
        _mint(_to, _amount);
        // @dev if the _to address is 'frozen' we simply emit the event.
        if (!hasAccess(_to)) emit MintedToFrozen(_msgSender(), _to, _amount);
    }

    /**
     * @notice Transfer hook for the adapter to call.
     * @param _to The address to transfer tokens to.
     * @param _amount The amount of tokens to transfer.
     */
    function adapterTransfer(address _to, uint256 _amount) external virtual onlyRole(ADAPTER_ROLE) {
        _transfer(_msgSender(), _to, _amount);
        if (!hasAccess(_to)) emit TransferredToFrozen(_msgSender(), _to, _amount);
    }
}
