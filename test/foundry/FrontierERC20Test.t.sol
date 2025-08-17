// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable-v4/utils/StringsUpgradeable.sol";

import { FrontierERC20F } from "../../contracts/FrontierERC20F.sol";
import { LibErrors } from "../../contracts/fireblocks/library/LibErrors.sol";
import { IERC20Errors } from "../../contracts/fireblocks/library/interface/IERC20Errors.sol";

import { MockAccessRegistry } from "../mocks/MockAccessRegistry.sol";

contract FrontierERC20Test is Test {
    FrontierERC20F public token;
    MockAccessRegistry public mockAccessRegistry;

    address defaultAdmin = makeAddr("defaultAdmin");
    address minter = makeAddr("minter");
    address pauser = makeAddr("pauser");
    address adapter = makeAddr("adapter");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address frozenUser = makeAddr("frozenUser");

    string constant TOKEN_NAME = "FRNT Token";
    string constant TOKEN_SYMBOL = "FRNT";

    event MintedToFrozen(address indexed caller, address indexed to, uint256 amount);
    event TransferredToFrozen(address indexed caller, address indexed to, uint256 amount);

    function setUp() public {
        mockAccessRegistry = new MockAccessRegistry();
        token = _deployProxy();
    }

    function _deployProxy() internal returns (FrontierERC20F) {
        // Deploy implementation
        FrontierERC20F implementation = new FrontierERC20F();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            FrontierERC20F.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            defaultAdmin,
            minter,
            pauser
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        return FrontierERC20F(address(proxy));
    }

    function test_initialize_Success() public view {
        assertEq(token.name(), TOKEN_NAME, "Token name should be set correctly");
        assertEq(token.symbol(), TOKEN_SYMBOL, "Token symbol should be set correctly");
        assertEq(token.decimals(), 6, "Token decimals should be 6");
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), defaultAdmin), "Default admin role should be granted");
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter), "Minter role should be granted");
        assertTrue(token.hasRole(token.PAUSER_ROLE(), pauser), "Pauser role should be granted");
    }

    function test_initialize_ZeroAddressDefaultAdmin() public {
        FrontierERC20F implementation = new FrontierERC20F();

        bytes memory initData = abi.encodeWithSelector(
            FrontierERC20F.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(0), // Zero address for defaultAdmin
            minter,
            pauser
        );

        vm.expectRevert(LibErrors.InvalidAddress.selector);
        new ERC1967Proxy(address(implementation), initData);
    }

    function test_initialize_ZeroAddressPauser() public {
        FrontierERC20F implementation = new FrontierERC20F();

        bytes memory initData = abi.encodeWithSelector(
            FrontierERC20F.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            defaultAdmin,
            minter,
            address(0) // Zero address for pauser
        );

        vm.expectRevert(LibErrors.InvalidAddress.selector);
        new ERC1967Proxy(address(implementation), initData);
    }

    function test_initialize_CannotInitializeTwice() public {
        // Attempting to initialize again should revert
        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize(TOKEN_NAME, TOKEN_SYMBOL, defaultAdmin, minter, pauser);
    }

    function test_decimals_Returns6() public view {
        assertEq(token.decimals(), 6, "Decimals should be 6 (overridden from default 18)");
    }

    function test_hasAccess_NoAccessRegistry() public view {
        // When no access registry is set, should return true for any address
        assertTrue(token.hasAccess(user1), "Should return true when no access registry is set");
        assertTrue(token.hasAccess(user2), "Should return true when no access registry is set");
        assertTrue(token.hasAccess(address(0)), "Should return true even for zero address when no registry");
    }

    function test_hasAccess_WithAccessRegistry_HasAccess() public {
        // Grant CONTRACT_ADMIN_ROLE to defaultAdmin for access registry updates
        vm.startPrank(defaultAdmin);
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);

        // Set access registry
        token.accessRegistryUpdate(address(mockAccessRegistry));

        vm.stopPrank();

        // Grant access to user1
        mockAccessRegistry.setAccess(user1, true);

        assertTrue(token.hasAccess(user1), "Should return true when user has access in registry");
    }

    function test_hasAccess_WithAccessRegistry_NoAccess() public {
        vm.startPrank(defaultAdmin);

        // Grant CONTRACT_ADMIN_ROLE to defaultAdmin for access registry updates
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);

        // Set access registry
        token.accessRegistryUpdate(address(mockAccessRegistry));

        vm.stopPrank();

        // Don't grant access to user2 (default is false)
        assertFalse(token.hasAccess(user2), "Should return false when user has no access in registry");
    }

    function test_burn_Success() public {
        // Grant adapter role
        vm.startPrank(defaultAdmin);
        token.grantRole(token.ADAPTER_ROLE(), adapter);
        vm.stopPrank();

        // Mint some tokens to user1 first
        vm.prank(minter);
        token.mint(user1, 1000e6);

        // Grant CONTRACT_ADMIN_ROLE and access to user1
        vm.startPrank(defaultAdmin);
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        vm.stopPrank();

        vm.prank(defaultAdmin);
        token.accessRegistryUpdate(address(mockAccessRegistry));
        mockAccessRegistry.setAccess(user1, true);

        uint256 burnAmount = 300e6;
        uint256 balanceBefore = token.balanceOf(user1);

        // Burn tokens as adapter
        vm.prank(adapter);
        token.adapterBurn(user1, burnAmount);

        assertEq(token.balanceOf(user1), balanceBefore - burnAmount, "Balance should decrease by burn amount");
    }

    function test_burn_OnlyAdapterRole() public {
        // Try to burn without adapter role
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(user1),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(token.ADAPTER_ROLE()), 32)
            )
        );
        token.adapterBurn(user1, 100e6);
        vm.stopPrank();

        // Try with minter role (should fail)
        vm.startPrank(minter);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(minter),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(token.ADAPTER_ROLE()), 32)
            )
        );
        token.adapterBurn(user1, 100e6);
        vm.stopPrank();
    }

    function test_burn_ZeroAmount() public {
        // Grant adapter role
        vm.startPrank(defaultAdmin);
        token.grantRole(token.ADAPTER_ROLE(), adapter);
        vm.stopPrank();

        // Try to burn zero amount
        vm.prank(adapter);
        vm.expectRevert(LibErrors.ZeroAmount.selector);
        token.adapterBurn(user1, 0);
    }

    function test_burn_NoAccess() public {
        vm.startPrank(defaultAdmin);

        // Grant adapter role
        token.grantRole(token.ADAPTER_ROLE(), adapter);

        // Grant CONTRACT_ADMIN_ROLE for access registry updates
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);

        // Set access registry but don't grant access to user1
        token.accessRegistryUpdate(address(mockAccessRegistry));

        vm.stopPrank();

        // Try to burn from user without access
        vm.startPrank(adapter);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, user1));
        token.adapterBurn(user1, 100e6);
        vm.stopPrank();
    }

    function test_mintToFrozen_Success() public {
        // Grant adapter role
        vm.startPrank(defaultAdmin);
        token.grantRole(token.ADAPTER_ROLE(), adapter);
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        token.accessRegistryUpdate(address(mockAccessRegistry));
        vm.stopPrank();

        uint256 mintAmount = 500e6;
        uint256 balanceBefore = token.balanceOf(frozenUser);

        mockAccessRegistry.setAccess(frozenUser, false);

        // Expect the event
        vm.expectEmit(true, true, false, true);
        emit MintedToFrozen(adapter, frozenUser, mintAmount);

        // Mint to frozen user
        vm.prank(adapter);
        token.adapterMint(frozenUser, mintAmount);

        assertEq(token.balanceOf(frozenUser), balanceBefore + mintAmount, "Balance should increase by mint amount");
    }

    function test_mintToFrozen_OnlyAdapterRole() public {
        // Try to mint without adapter role
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(user1),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(token.ADAPTER_ROLE()), 32)
            )
        );
        token.adapterMint(frozenUser, 100e6);
        vm.stopPrank();
    }

    function test_transferToFrozen_Success() public {
        // Grant adapter role
        vm.startPrank(defaultAdmin);
        token.grantRole(token.ADAPTER_ROLE(), adapter);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        token.accessRegistryUpdate(address(mockAccessRegistry));
        vm.stopPrank();

        mockAccessRegistry.setAccess(frozenUser, false);
        mockAccessRegistry.setAccess(adapter, true);

        // First mint some tokens to the adapter
        vm.prank(minter);
        token.mint(adapter, 1000e6);

        uint256 transferAmount = 200e6;
        uint256 adapterBalanceBefore = token.balanceOf(adapter);
        uint256 frozenBalanceBefore = token.balanceOf(frozenUser);

        // Expect the event
        vm.expectEmit(true, true, false, true);
        emit TransferredToFrozen(adapter, frozenUser, transferAmount);

        // Transfer to frozen user
        vm.prank(adapter);
        token.adapterTransfer(frozenUser, transferAmount);

        assertEq(token.balanceOf(adapter), adapterBalanceBefore - transferAmount, "Adapter balance should decrease");
        assertEq(
            token.balanceOf(frozenUser),
            frozenBalanceBefore + transferAmount,
            "Frozen user balance should increase"
        );
    }

    function test_transferToFrozen_OnlyAdapterRole() public {
        // Try to transfer without adapter role
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(user1),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(token.ADAPTER_ROLE()), 32)
            )
        );
        token.adapterTransfer(frozenUser, 100e6);
        vm.stopPrank();

        // Try with minter role (should fail)
        vm.startPrank(minter);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(minter),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(token.ADAPTER_ROLE()), 32)
            )
        );
        token.adapterTransfer(frozenUser, 100e6);
        vm.stopPrank();
    }

    function test_adapterRole_CanBeGrantedAndRevoked() public {
        // Initially adapter should not have role
        assertFalse(token.hasRole(token.ADAPTER_ROLE(), adapter), "Adapter should not have role initially");

        vm.startPrank(defaultAdmin);

        // Grant adapter role
        token.grantRole(token.ADAPTER_ROLE(), adapter);

        assertTrue(token.hasRole(token.ADAPTER_ROLE(), adapter), "Adapter should have role after granting");

        // Revoke adapter role
        token.revokeRole(token.ADAPTER_ROLE(), adapter);

        vm.stopPrank();

        assertFalse(token.hasRole(token.ADAPTER_ROLE(), adapter), "Adapter should not have role after revoking");
    }

    function testFuzz_burn_ValidAmounts(uint256 amount) public {
        // Limit to reasonable amounts to avoid overflow
        vm.assume(amount > 0 && amount <= 1e12 * 1e6); // Max 1 trillion tokens

        vm.startPrank(defaultAdmin);

        // Grant adapter role
        token.grantRole(token.ADAPTER_ROLE(), adapter);

        // Grant CONTRACT_ADMIN_ROLE and set access registry
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);

        // Set access registry and grant access
        token.accessRegistryUpdate(address(mockAccessRegistry));
        mockAccessRegistry.setAccess(user1, true);

        vm.stopPrank();

        // Mint tokens first
        vm.prank(minter);
        token.mint(user1, amount);

        uint256 balanceBefore = token.balanceOf(user1);

        // Burn tokens
        vm.prank(adapter);
        token.adapterBurn(user1, amount);

        assertEq(
            token.balanceOf(user1),
            balanceBefore - amount,
            "Balance should decrease correctly for any valid amount"
        );
    }

    function testFuzz_mintToFrozen_ValidAmounts(uint256 amount) public {
        // Limit to reasonable amounts to avoid overflow
        vm.assume(amount > 0 && amount <= 1e12 * 1e6); // Max 1 trillion tokens

        // Grant adapter role
        vm.startPrank(defaultAdmin);
        token.grantRole(token.ADAPTER_ROLE(), adapter);
        vm.stopPrank();

        uint256 balanceBefore = token.balanceOf(frozenUser);

        // Mint to frozen user
        vm.prank(adapter);
        token.adapterMint(frozenUser, amount);

        assertEq(
            token.balanceOf(frozenUser),
            balanceBefore + amount,
            "Balance should increase correctly for any valid amount"
        );
    }

    function test_pausedContract_BlocksAllTokenOperations() public {
        // Setup: Grant all necessary roles BEFORE pausing
        vm.startPrank(defaultAdmin);
        token.grantRole(token.ADAPTER_ROLE(), adapter);
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        token.grantRole(token.BURNER_ROLE(), defaultAdmin); // Grant this before pausing
        token.accessRegistryUpdate(address(mockAccessRegistry));
        vm.stopPrank();

        // Grant access to users
        mockAccessRegistry.setAccess(user1, true);
        mockAccessRegistry.setAccess(user2, true);
        mockAccessRegistry.setAccess(adapter, true); // Grant access to adapter for transfers
        mockAccessRegistry.setAccess(defaultAdmin, true); // Grant access to defaultAdmin for burn

        // Mint some tokens to user1 for transfer/burn tests
        vm.prank(minter);
        token.mint(user1, 1000e6);

        // Also mint some tokens to adapter for transfer tests
        vm.prank(minter);
        token.mint(adapter, 500e6);

        // Mint some tokens to defaultAdmin for burn tests
        vm.prank(minter);
        token.mint(defaultAdmin, 200e6);

        // Verify operations work when not paused
        uint256 initialBalance = token.balanceOf(user1);
        assertEq(initialBalance, 1000e6, "Initial mint should succeed when not paused");

        // Pause the contract
        vm.prank(pauser);
        token.pause();

        assertTrue(token.paused(), "Contract should be paused");

        // Test 1: Minting should fail when paused
        vm.startPrank(minter);
        vm.expectRevert("Pausable: paused");
        token.mint(user2, 500e6);
        vm.stopPrank();

        // Test 2: Adapter minting should fail when paused
        vm.startPrank(adapter);
        vm.expectRevert("Pausable: paused");
        token.adapterMint(user2, 500e6);
        vm.stopPrank();

        // Test 3: Burning should fail when paused
        vm.startPrank(defaultAdmin);
        vm.expectRevert("Pausable: paused");
        token.burn(100e6);
        vm.stopPrank();

        // Test 4: Adapter burning should fail when paused
        vm.startPrank(adapter);
        vm.expectRevert("Pausable: paused");
        token.adapterBurn(user1, 100e6);
        vm.stopPrank();

        // Test 5: Regular transfer should fail when paused
        vm.startPrank(user1);
        vm.expectRevert("Pausable: paused");
        token.transfer(user2, 100e6);
        vm.stopPrank();

        // Test 6: Approve should fail when paused
        vm.startPrank(user1);
        vm.expectRevert("Pausable: paused");
        token.approve(user2, 100e6);
        vm.stopPrank();

        // Test 7: Adapter transfer should fail when paused
        vm.startPrank(adapter);
        vm.expectRevert("Pausable: paused");
        token.adapterTransfer(user2, 100e6);
        vm.stopPrank();

        // Verify balances haven't changed due to failed operations
        assertEq(token.balanceOf(user1), 1000e6, "User1 balance should remain unchanged when paused");
        assertEq(token.balanceOf(user2), 0, "User2 balance should remain zero when paused");
        assertEq(token.balanceOf(adapter), 500e6, "Adapter balance should remain unchanged when paused");
        assertEq(token.balanceOf(defaultAdmin), 200e6, "DefaultAdmin balance should remain unchanged when paused");

        // Unpause and verify operations work again
        vm.prank(pauser);
        token.unpause();

        assertFalse(token.paused(), "Contract should be unpaused");

        // Test that operations work again after unpausing
        vm.prank(minter);
        token.mint(user2, 500e6);
        assertEq(token.balanceOf(user2), 500e6, "Minting should work after unpause");

        vm.prank(user1);
        token.transfer(user2, 100e6);
        assertEq(token.balanceOf(user1), 900e6, "Transfer should work after unpause");
        assertEq(token.balanceOf(user2), 600e6, "Transfer should work after unpause");

        // Test burning works after unpause
        vm.prank(defaultAdmin);
        token.burn(50e6);
        assertEq(token.balanceOf(defaultAdmin), 150e6, "Burn should work after unpause (200e6 - 50e6 = 150e6)");
    }
}
