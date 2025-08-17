// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable-v4/token/ERC20/IERC20Upgradeable.sol";
import { IERC20MetadataUpgradeable } from "@openzeppelin/contracts-upgradeable-v4/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { IERC20Errors } from "../../contracts/fireblocks/library/interface/IERC20Errors.sol";

import { FrontierVault } from "../../contracts/FrontierVault.sol";
import { FrontierERC20F } from "../../contracts/FrontierERC20F.sol";

import { ERC20Mock, ERC20MockNoDecimals } from "../mocks/ERC20Mock.sol";
import { MockAccessRegistry } from "../mocks/MockAccessRegistry.sol";

contract FrontierVaultTest is Test {
    FrontierVault public vault;
    ERC20Mock public asset;
    ERC20MockNoDecimals public assetNoDecimals;
    MockAccessRegistry public mockAccessRegistry;

    address defaultAdmin = makeAddr("defaultAdmin");
    address minter = makeAddr("minter");
    address pauser = makeAddr("pauser");

    string constant VAULT_NAME = "FRNT Vault";
    string constant VAULT_SYMBOL = "vFRNT";

    function setUp() public {
        mockAccessRegistry = new MockAccessRegistry();
        asset = new ERC20Mock("FRNT Asset", "FRNT", 6);
        assetNoDecimals = new ERC20MockNoDecimals("No Decimals Token", "NDT");
    }

    function _deployVaultProxy(IERC20Upgradeable _asset) internal returns (FrontierVault) {
        FrontierVault implementation = new FrontierVault();
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,address,address,address,address)",
            VAULT_NAME,
            VAULT_SYMBOL,
            defaultAdmin,
            minter,
            pauser,
            _asset
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        return FrontierVault(address(proxy));
    }

    function test_constructor_DisablesInitializers() public {
        // Create a new implementation
        FrontierVault implementation = new FrontierVault();

        // Attempting to initialize the implementation directly should revert
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        (bool success, ) = address(implementation).call(
            abi.encodeWithSignature(
                "initialize(string,string,address,address,address,address)",
                VAULT_NAME,
                VAULT_SYMBOL,
                defaultAdmin,
                minter,
                pauser,
                IERC20Upgradeable(address(asset))
            )
        );

        assertFalse(success, "Initialization should succeed");
    }

    function test_initialize_ERC20InitializerDisabled() public {
        // Deploy implementation
        FrontierVault implementation = new FrontierVault();

        // Attempting to use the base FrontierERC20F initializer should revert
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,address,address,address)",
            VAULT_NAME,
            VAULT_SYMBOL,
            defaultAdmin,
            minter,
            pauser
        );

        vm.expectRevert("FrontierVault: FrontierERC20F initializer disabled, use initialize with asset");
        new ERC1967Proxy(address(implementation), initData);
    }

    function test_initialize_Success() public {
        vault = _deployVaultProxy(IERC20Upgradeable(address(asset)));

        // Verify initialization was successful
        assertEq(vault.name(), VAULT_NAME, "Vault name should be set correctly");
        assertEq(vault.symbol(), VAULT_SYMBOL, "Vault symbol should be set correctly");
        assertEq(address(vault.asset()), address(asset), "Asset should be set correctly");
        assertEq(vault.decimals(), 6, "Decimals should match asset decimals");
    }

    function test_initialize_WithAssetNoDecimals() public {
        vault = _deployVaultProxy(IERC20Upgradeable(address(assetNoDecimals)));

        // Verify initialization with asset that doesn't have decimals function
        assertEq(vault.name(), VAULT_NAME, "Vault name should be set correctly");
        assertEq(vault.symbol(), VAULT_SYMBOL, "Vault symbol should be set correctly");
        assertEq(address(vault.asset()), address(assetNoDecimals), "Asset should be set correctly");
        assertEq(vault.decimals(), 18, "Decimals should default to 18 when asset decimals unavailable");
    }

    function test_initialize_WithDifferentAssetDecimals() public {
        // Test with 18 decimal asset
        ERC20Mock asset18 = new ERC20Mock("Asset 18", "A18", 18);
        vault = _deployVaultProxy(IERC20Upgradeable(address(asset18)));
        assertEq(vault.decimals(), 18, "Should handle 18 decimal asset");

        // Test with 0 decimal asset
        ERC20Mock asset0 = new ERC20Mock("Asset 0", "A0", 0);
        FrontierVault vault0 = _deployVaultProxy(IERC20Upgradeable(address(asset0)));
        assertEq(vault0.decimals(), 0, "Should handle 0 decimal asset");

        // Test with 12 decimal asset
        ERC20Mock asset12 = new ERC20Mock("Asset 12", "A12", 12);
        FrontierVault vault12 = _deployVaultProxy(IERC20Upgradeable(address(asset12)));
        assertEq(vault12.decimals(), 12, "Should handle 12 decimal asset");
    }

    function test_initialize_CannotInitializeTwice() public {
        vault = _deployVaultProxy(IERC20Upgradeable(address(asset)));

        // Attempting to initialize again should revert
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        (bool success, ) = address(vault).call(
            abi.encodeWithSignature(
                "initialize(string,string,address,address,address,address)",
                VAULT_NAME,
                VAULT_SYMBOL,
                defaultAdmin,
                minter,
                pauser,
                IERC20Upgradeable(address(asset))
            )
        );

        assertFalse(success, "Initialization should succeed");
    }

    function test_initialize_DifferentParameters() public {
        vault = _deployVaultProxy(IERC20Upgradeable(address(asset)));

        // Test with different parameters
        ERC20Mock asset2 = new ERC20Mock("Asset 2", "A2", 8);
        FrontierVault vault2 = _deployVaultProxy(IERC20Upgradeable(address(asset2)));

        // Verify different vaults have different configurations
        assertEq(address(vault.asset()), address(asset), "First vault should have first asset");
        assertEq(address(vault2.asset()), address(asset2), "Second vault should have second asset");
        assertEq(vault.decimals(), 6, "First vault should have 6 decimals");
        assertEq(vault2.decimals(), 8, "Second vault should have 8 decimals");
    }

    function test_initialize_CannotInitializeWithZeroAddressAsset() public {
        FrontierVault implementation = new FrontierVault();
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,address,address,address,address)",
            VAULT_NAME,
            VAULT_SYMBOL,
            defaultAdmin,
            minter,
            pauser,
            IERC20Upgradeable(address(0))
        );

        // Should revert
        vm.expectRevert("FrontierVault: asset cannot be zero address");
        new ERC1967Proxy(address(implementation), initData);
    }

    function test_initialize_PreservesFRNTERC20Functionality() public {
        vault = _deployVaultProxy(IERC20Upgradeable(address(asset)));

        // Verify that underlying FrontierERC20F functionality is preserved
        assertEq(vault.name(), VAULT_NAME, "Name should be preserved");
        assertEq(vault.symbol(), VAULT_SYMBOL, "Symbol should be preserved");

        // Check that roles are properly set up (basic test)
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), defaultAdmin), "Default admin role should be set");
    }

    function test_constructor_SetsCorrectInheritance() public {
        vault = _deployVaultProxy(IERC20Upgradeable(address(asset)));

        // Verify the vault properly inherits from both FrontierERC20F and implements IERC4626
        assertEq(vault.name(), VAULT_NAME, "Should inherit ERC20 name functionality");
        assertEq(vault.symbol(), VAULT_SYMBOL, "Should inherit ERC20 symbol functionality");
        assertEq(address(vault.asset()), address(asset), "Should implement IERC4626 asset functionality");
    }

    function testFuzz_initialize_ValidDecimals(uint8 assetDecimals) public {
        // Test with fuzzed decimal values
        ERC20Mock fuzzAsset = new ERC20Mock("Fuzz Asset", "FUZZ", assetDecimals);
        vault = _deployVaultProxy(IERC20Upgradeable(address(fuzzAsset)));

        assertEq(vault.decimals(), assetDecimals, "Vault decimals should match asset decimals");
        assertEq(address(vault.asset()), address(fuzzAsset), "Asset should be set correctly");
    }

    function testFuzz_initialize_ValidAddresses(address _defaultAdmin, address _minter, address _pauser) public {
        // Skip zero addresses and precompiled contracts
        vm.assume(_defaultAdmin != address(0) && _defaultAdmin.code.length == 0);
        vm.assume(_minter != address(0) && _minter.code.length == 0);
        vm.assume(_pauser != address(0) && _pauser.code.length == 0);

        // Also assume they're all different
        vm.assume(_defaultAdmin != _minter && _defaultAdmin != _pauser && _minter != _pauser);

        FrontierVault implementation = new FrontierVault();
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,address,address,address,address)",
            VAULT_NAME,
            VAULT_SYMBOL,
            _defaultAdmin,
            _minter,
            _pauser,
            IERC20Upgradeable(address(asset))
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        FrontierVault fuzzVault = FrontierVault(address(proxy));

        // Verify initialization succeeded with fuzzed addresses
        assertEq(fuzzVault.name(), VAULT_NAME, "Name should be set correctly");
        assertEq(fuzzVault.symbol(), VAULT_SYMBOL, "Symbol should be set correctly");
        assertEq(address(fuzzVault.asset()), address(asset), "Asset should be set correctly");
    }

    function test_deposit_ShouldRevertIfReceiverInAccessRegistry() public {
        vault = _deployVaultProxy(IERC20Upgradeable(address(asset)));

        // Setup access registry
        vm.startPrank(defaultAdmin);
        vault.grantRole(vault.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        vault.accessRegistryUpdate(address(mockAccessRegistry));
        vm.stopPrank();

        address depositor = makeAddr("depositor");
        address receiver = makeAddr("receiver");
        uint256 assets = 1000e6;

        // Add receiver to access registry (should cause revert)
        mockAccessRegistry.setAccess(receiver, false);

        // Give depositor some asset tokens
        asset.mint(depositor, assets);

        vm.startPrank(depositor);
        asset.approve(address(vault), assets);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, receiver));
        vault.deposit(assets, receiver);
        vm.stopPrank();
    }

    function test_mint_ShouldRevertIfReceiverInAccessRegistry() public {
        vault = _deployVaultProxy(IERC20Upgradeable(address(asset)));

        // Setup access registry
        vm.startPrank(defaultAdmin);
        vault.grantRole(vault.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        vault.accessRegistryUpdate(address(mockAccessRegistry));
        vm.stopPrank();

        address caller = makeAddr("caller");
        address receiver = makeAddr("receiver");
        uint256 shares = 1000e6;

        mockAccessRegistry.setAccess(receiver, false);

        // Calculate required assets for shares
        uint256 assets = vault.previewMint(shares);

        // Give caller some asset tokens
        asset.mint(caller, assets);

        vm.startPrank(caller);
        asset.approve(address(vault), assets);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, receiver));
        vault.mint(shares, receiver);
        vm.stopPrank();
    }

    function test_withdraw_ShouldRevertIfOwnerInAccessRegistry() public {
        vault = _deployVaultProxy(IERC20Upgradeable(address(asset)));

        // Setup access registry
        vm.startPrank(defaultAdmin);
        vault.grantRole(vault.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        vault.accessRegistryUpdate(address(mockAccessRegistry));
        vm.stopPrank();

        address owner = makeAddr("owner");
        address receiver = makeAddr("receiver");
        uint256 depositAssets = 1000e6;

        // First, deposit some assets to create shares (owner not in registry initially)
        mockAccessRegistry.setAccess(owner, true);
        asset.mint(owner, depositAssets);
        vm.startPrank(owner);
        asset.approve(address(vault), depositAssets);
        vault.deposit(depositAssets, owner);
        vm.stopPrank();

        // Now add owner to access registry
        mockAccessRegistry.setAccess(owner, false);

        uint256 withdrawAssets = 500e6;

        // Withdraw should revert because owner is in access registry
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, owner));
        vault.withdraw(withdrawAssets, receiver, owner);
    }

    function test_redeem_ShouldRevertIfOwnerInAccessRegistry() public {
        vault = _deployVaultProxy(IERC20Upgradeable(address(asset)));

        // Setup access registry
        vm.startPrank(defaultAdmin);
        vault.grantRole(vault.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        vault.accessRegistryUpdate(address(mockAccessRegistry));
        vm.stopPrank();

        address owner = makeAddr("owner");
        address receiver = makeAddr("receiver");
        uint256 depositAssets = 1000e6;

        // First, deposit some assets to create shares (owner not in registry initially)
        mockAccessRegistry.setAccess(owner, true);
        asset.mint(owner, depositAssets);
        vm.startPrank(owner);
        asset.approve(address(vault), depositAssets);
        uint256 shares = vault.deposit(depositAssets, owner);
        vm.stopPrank();

        // Now add owner to access registry
        mockAccessRegistry.setAccess(owner, false);

        uint256 redeemShares = shares / 2; // Redeem half

        // Redeem should revert because owner is in access registry
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, owner));
        vault.redeem(redeemShares, receiver, owner);
    }
}
