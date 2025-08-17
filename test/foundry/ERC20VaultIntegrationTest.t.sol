// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { FrontierERC20F } from "../../contracts/FrontierERC20F.sol";
import { FrontierVault } from "../../contracts/FrontierVault.sol";

import { MockAccessRegistry } from "../mocks/MockAccessRegistry.sol";

/**
 * @title ERC20VaultIntegrationTest
 * @notice Integration tests for FrontierERC20 as asset tokens in FrontierVault
 * @dev Tests ERC4626 functionality: deposit, mint, withdraw, redeem with 6 decimals
 */
contract ERC20VaultIntegrationTest is Test {
    FrontierERC20F public assetToken;
    FrontierVault public vault;
    MockAccessRegistry public mockAccessRegistry;

    address defaultAdmin = makeAddr("defaultAdmin");
    address minter = makeAddr("minter");
    address pauser = makeAddr("pauser");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address receiver = makeAddr("receiver");

    string constant ASSET_NAME = "FRNT Asset Token";
    string constant ASSET_SYMBOL = "FRNT";
    string constant VAULT_NAME = "FRNT Vault Token";
    string constant VAULT_SYMBOL = "vFRNT";

    // Test amounts
    uint256 constant INITIAL_DEPOSIT = 1000e6; // 1000 tokens with 6 decimals
    uint256 constant LARGE_AMOUNT = 1e12 * 1e6; // 1 trillion tokens

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    function setUp() public {
        mockAccessRegistry = new MockAccessRegistry();

        // Grant access to all test users
        mockAccessRegistry.setAccess(user1, true);
        mockAccessRegistry.setAccess(user2, true);
        mockAccessRegistry.setAccess(receiver, true);
        mockAccessRegistry.setAccess(defaultAdmin, true);
        mockAccessRegistry.setAccess(minter, true);

        assetToken = _deployAssetToken();
        vault = _deployVault(assetToken);
    }

    function _deployAssetToken() internal returns (FrontierERC20F) {
        // Deploy asset token implementation
        FrontierERC20F implementation = new FrontierERC20F();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            FrontierERC20F.initialize.selector,
            ASSET_NAME,
            ASSET_SYMBOL,
            defaultAdmin,
            minter,
            pauser
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        FrontierERC20F token = FrontierERC20F(address(proxy));

        // Setup access registry and roles
        vm.startPrank(defaultAdmin);
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        token.accessRegistryUpdate(address(mockAccessRegistry));
        vm.stopPrank();

        return token;
    }

    function _deployVault(FrontierERC20F asset) internal returns (FrontierVault) {
        // Deploy vault implementation
        FrontierVault implementation = new FrontierVault();

        // Prepare initialization data for the 6-parameter initialize function
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,address,address,address,address)",
            VAULT_NAME,
            VAULT_SYMBOL,
            defaultAdmin,
            minter,
            pauser,
            address(asset)
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        FrontierVault vaultContract = FrontierVault(address(proxy));

        // Grant access to the vault contract so it can receive/transfer tokens
        mockAccessRegistry.setAccess(address(vaultContract), true);

        return vaultContract;
    }

    function _mintAssetTokens(address to, uint256 amount) internal {
        vm.prank(minter);
        assetToken.mint(to, amount);
    }

    function _approveVault(address user, uint256 amount) internal {
        vm.prank(user);
        assetToken.approve(address(vault), amount);
    }

    function test_setup_6Decimals() public view {
        // Verify setup
        assertEq(address(vault.asset()), address(assetToken), "Asset should be set correctly");
        assertEq(vault.decimals(), 6, "Vault should have 6 decimals");
        assertEq(assetToken.decimals(), 6, "Asset should have 6 decimals");
        assertEq(vault.totalSupply(), 0, "Initial vault supply should be 0");
        assertEq(vault.totalAssets(), 0, "Initial vault assets should be 0");
    }

    function test_deposit_Success() public {
        _mintAssetTokens(user1, INITIAL_DEPOSIT);
        _approveVault(user1, INITIAL_DEPOSIT);

        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, user1, INITIAL_DEPOSIT, INITIAL_DEPOSIT);

        vm.prank(user1);
        uint256 shares = vault.deposit(INITIAL_DEPOSIT, user1);

        // Verify results
        assertEq(shares, INITIAL_DEPOSIT, "Should return expected shares");
        assertEq(vault.balanceOf(user1), shares, "User should receive shares");
        assertEq(vault.totalAssets(), INITIAL_DEPOSIT, "Vault should hold deposited assets");
        assertEq(assetToken.balanceOf(address(vault)), INITIAL_DEPOSIT, "Vault should hold asset tokens");
        assertEq(assetToken.balanceOf(user1), 0, "User should have spent asset tokens");
    }

    function test_deposit_ToReceiver() public {
        _mintAssetTokens(user1, INITIAL_DEPOSIT);
        _approveVault(user1, INITIAL_DEPOSIT);

        vm.prank(user1);
        uint256 shares = vault.deposit(INITIAL_DEPOSIT, receiver);

        // Verify receiver gets shares, not the depositor
        assertEq(vault.balanceOf(receiver), shares, "Receiver should get shares");
        assertEq(vault.balanceOf(user1), 0, "Depositor should not get shares");
        assertEq(assetToken.balanceOf(user1), 0, "Depositor should have spent assets");
    }

    function test_mint_Success() public {
        uint256 sharesToMint = 500e6; // 500 shares
        uint256 expectedAssets = vault.previewMint(sharesToMint);

        _mintAssetTokens(user1, expectedAssets);
        _approveVault(user1, expectedAssets);

        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, user1, expectedAssets, sharesToMint);

        vm.prank(user1);
        uint256 assets = vault.mint(sharesToMint, user1);

        // Verify results
        assertEq(assets, expectedAssets, "Should return expected assets");
        assertEq(vault.balanceOf(user1), sharesToMint, "User should receive exact shares");
        assertEq(vault.totalAssets(), expectedAssets, "Vault should hold expected assets");
    }

    function test_withdraw_Success() public {
        // First deposit to have something to withdraw
        _mintAssetTokens(user1, INITIAL_DEPOSIT);
        _approveVault(user1, INITIAL_DEPOSIT);
        vm.prank(user1);
        vault.deposit(INITIAL_DEPOSIT, user1);

        // Now withdraw
        uint256 assetsToWithdraw = INITIAL_DEPOSIT / 2; // Withdraw half
        uint256 expectedShares = vault.previewWithdraw(assetsToWithdraw);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(user1, user1, user1, assetsToWithdraw, expectedShares);

        vm.prank(user1);
        uint256 shares = vault.withdraw(assetsToWithdraw, user1, user1);

        // Verify results
        assertEq(shares, expectedShares, "Should return expected shares");
        assertEq(assetToken.balanceOf(user1), assetsToWithdraw, "User should receive withdrawn assets");
        assertEq(vault.totalAssets(), INITIAL_DEPOSIT - assetsToWithdraw, "Vault assets should decrease");
    }

    function test_withdraw_ToReceiver() public {
        // Deposit
        _mintAssetTokens(user1, INITIAL_DEPOSIT);
        _approveVault(user1, INITIAL_DEPOSIT);
        vm.prank(user1);
        vault.deposit(INITIAL_DEPOSIT, user1);

        // Withdraw to different receiver
        uint256 assetsToWithdraw = INITIAL_DEPOSIT / 2;

        vm.prank(user1);
        vault.withdraw(assetsToWithdraw, receiver, user1);

        // Verify receiver gets assets, owner loses shares
        assertEq(assetToken.balanceOf(receiver), assetsToWithdraw, "Receiver should get assets");
        assertEq(assetToken.balanceOf(user1), 0, "Owner should not get assets");
        assertLt(vault.balanceOf(user1), INITIAL_DEPOSIT, "Owner should lose shares");
    }

    function test_redeem_Success() public {
        // Deposit
        _mintAssetTokens(user1, INITIAL_DEPOSIT);
        _approveVault(user1, INITIAL_DEPOSIT);
        vm.prank(user1);
        uint256 totalShares = vault.deposit(INITIAL_DEPOSIT, user1);

        // Redeem half shares
        uint256 sharesToRedeem = totalShares / 2;
        uint256 expectedAssets = vault.previewRedeem(sharesToRedeem);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(user1, user1, user1, expectedAssets, sharesToRedeem);

        vm.prank(user1);
        uint256 assets = vault.redeem(sharesToRedeem, user1, user1);

        // Verify results
        assertEq(assets, expectedAssets, "Should return expected assets");
        assertEq(vault.balanceOf(user1), totalShares - sharesToRedeem, "User should lose redeemed shares");
        assertEq(assetToken.balanceOf(user1), expectedAssets, "User should receive redeemed assets");
    }
}
