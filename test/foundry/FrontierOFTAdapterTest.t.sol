// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { FrontierOFTAdapter } from "../../contracts/FrontierOFTAdapter.sol";
import { FrontierERC20F } from "../../contracts/FrontierERC20F.sol";
import { IFrontierERC20F } from "../../contracts/interfaces/IFrontierERC20F.sol";
import { IERC20Errors } from "../../contracts/fireblocks/library/interface/IERC20Errors.sol";

import { MockAccessRegistry } from "../mocks/MockAccessRegistry.sol";
import { MockLayerZeroEndpoint } from "../mocks/MockLayerZeroEndpoint.sol";
import { MockFrontierOFTAdapter } from "../mocks/MockFrontierOFTAdapter.sol";

contract FrontierOFTAdapterTest is Test {
    FrontierOFTAdapter public adapter;
    MockFrontierOFTAdapter public mockAdapter;
    FrontierERC20F public token;
    MockAccessRegistry public mockAccessRegistry;
    MockLayerZeroEndpoint public mockEndpoint;

    address delegate = makeAddr("delegate");
    address defaultAdmin = makeAddr("defaultAdmin");
    address minter = makeAddr("minter");
    address pauser = makeAddr("pauser");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address frozenUser = makeAddr("frozenUser");

    string constant TOKEN_NAME = "FRNT Token";
    string constant TOKEN_SYMBOL = "FRNT";
    uint256 constant TRANSFER_AMOUNT = 1000e6;

    event TransferredToFrozen(address indexed caller, address indexed to, uint256 amount);

    function setUp() public {
        mockAccessRegistry = new MockAccessRegistry();
        mockEndpoint = new MockLayerZeroEndpoint();

        // Deploy FrontierERC20 through proxy
        FrontierERC20F tokenImplementation = new FrontierERC20F();
        bytes memory tokenInitData = abi.encodeWithSelector(
            FrontierERC20F.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            defaultAdmin,
            minter,
            pauser
        );
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        token = FrontierERC20F(address(tokenProxy));

        // Deploy the adapter
        adapter = new FrontierOFTAdapter(address(token), address(mockEndpoint));

        // Deploy testable adapter through proxy for proper initialization
        MockFrontierOFTAdapter testableImplementation = new MockFrontierOFTAdapter(
            address(token),
            address(mockEndpoint)
        );
        bytes memory initData = abi.encodeWithSelector(FrontierOFTAdapter.initialize.selector, delegate);
        ERC1967Proxy testableProxy = new ERC1967Proxy(address(testableImplementation), initData);
        mockAdapter = MockFrontierOFTAdapter(address(testableProxy));

        // Setup roles and access registry
        vm.startPrank(defaultAdmin);
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        token.grantRole(token.ADAPTER_ROLE(), address(mockAdapter));
        token.accessRegistryUpdate(address(mockAccessRegistry));
        vm.stopPrank();

        // Grant access to the testableAdapter so it can receive tokens
        mockAccessRegistry.setAccess(address(mockAdapter), true);
    }

    function test_constructor_SetsTokenAndEndpoint() public {
        // Create a new adapter to test constructor
        FrontierOFTAdapter newAdapter = new FrontierOFTAdapter(address(token), address(mockEndpoint));

        // Verify the token is set correctly
        assertEq(address(newAdapter.token()), address(token), "Token should be set correctly in constructor");
    }

    function test_constructor_DisablesInitializers() public {
        // The constructor should disable initializers
        // We can verify this by trying to call initialize on the implementation directly
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        adapter.initialize(delegate);
    }

    function test_constructor_DifferentTokens() public {
        // Deploy another FrontierERC20F instance
        FrontierERC20F anotherTokenImpl = new FrontierERC20F();
        bytes memory anotherInitData = abi.encodeWithSelector(
            FrontierERC20F.initialize.selector,
            "Another Token",
            "ANOT",
            defaultAdmin,
            minter,
            pauser
        );
        ERC1967Proxy anotherProxy = new ERC1967Proxy(address(anotherTokenImpl), anotherInitData);
        FrontierERC20F anotherToken = FrontierERC20F(address(anotherProxy));

        FrontierOFTAdapter newAdapter = new FrontierOFTAdapter(address(anotherToken), address(mockEndpoint));

        assertEq(address(newAdapter.token()), address(anotherToken), "Should work with different tokens");
        assertNotEq(address(newAdapter.token()), address(token), "Should be different from original token");
    }

    function test_initialize_Success() public {
        // Deploy implementation
        FrontierOFTAdapter implementation = new FrontierOFTAdapter(address(token), address(mockEndpoint));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(FrontierOFTAdapter.initialize.selector, delegate);

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        FrontierOFTAdapter proxyAdapter = FrontierOFTAdapter(address(proxy));

        // Verify initialization was successful
        assertEq(proxyAdapter.owner(), delegate, "Delegate should be set as owner");
    }

    function test_initialize_CannotInitializeTwice() public {
        // Deploy and initialize adapter through proxy
        FrontierOFTAdapter implementation = new FrontierOFTAdapter(address(token), address(mockEndpoint));
        bytes memory initData = abi.encodeWithSelector(FrontierOFTAdapter.initialize.selector, delegate);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        FrontierOFTAdapter proxyAdapter = FrontierOFTAdapter(address(proxy));

        // Attempting to initialize again should revert
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        proxyAdapter.initialize(delegate);
    }

    function test_initialize_DifferentDelegates() public {
        address delegate1 = makeAddr("delegate1");
        address delegate2 = makeAddr("delegate2");

        // Test with delegate1
        FrontierOFTAdapter implementation1 = new FrontierOFTAdapter(address(token), address(mockEndpoint));
        bytes memory initData1 = abi.encodeWithSelector(FrontierOFTAdapter.initialize.selector, delegate1);
        ERC1967Proxy proxy1 = new ERC1967Proxy(address(implementation1), initData1);
        FrontierOFTAdapter adapter1 = FrontierOFTAdapter(address(proxy1));

        // Test with delegate2
        FrontierOFTAdapter implementation2 = new FrontierOFTAdapter(address(token), address(mockEndpoint));
        bytes memory initData2 = abi.encodeWithSelector(FrontierOFTAdapter.initialize.selector, delegate2);
        ERC1967Proxy proxy2 = new ERC1967Proxy(address(implementation2), initData2);
        FrontierOFTAdapter adapter2 = FrontierOFTAdapter(address(proxy2));

        assertEq(adapter1.owner(), delegate1, "First adapter should have delegate1");
        assertEq(adapter2.owner(), delegate2, "Second adapter should have delegate2");
    }

    function test_credit_UserWithAccess_NormalTransfer() public {
        // Give the adapter some tokens to transfer
        vm.prank(minter);
        token.mint(address(mockAdapter), TRANSFER_AMOUNT);

        // Give user1 access
        mockAccessRegistry.setAccess(user1, true);

        uint256 userBalanceBefore = token.balanceOf(user1);
        uint256 adapterBalanceBefore = token.balanceOf(address(mockAdapter));

        // Call the exposed _credit function
        uint256 amountReceived = mockAdapter.exposed_credit(user1, TRANSFER_AMOUNT, 1);

        // Verify normal transfer occurred
        assertEq(amountReceived, TRANSFER_AMOUNT, "Should return the full amount");
        assertEq(token.balanceOf(user1), userBalanceBefore + TRANSFER_AMOUNT, "User balance should increase");
        assertEq(
            token.balanceOf(address(mockAdapter)),
            adapterBalanceBefore - TRANSFER_AMOUNT,
            "Adapter balance should decrease"
        );
    }

    function test_credit_UserWithoutAccess_TransferToFrozen() public {
        // Give the adapter some tokens to transfer
        vm.prank(minter);
        token.mint(address(mockAdapter), TRANSFER_AMOUNT);

        // Don't give frozenUser access (default is false)
        mockAccessRegistry.setAccess(frozenUser, false);

        uint256 userBalanceBefore = token.balanceOf(frozenUser);
        uint256 adapterBalanceBefore = token.balanceOf(address(mockAdapter));

        // Expect the TransferredToFrozen event
        vm.expectEmit(true, true, false, true);
        emit TransferredToFrozen(address(mockAdapter), frozenUser, TRANSFER_AMOUNT);

        // Call the exposed _credit function
        uint256 amountReceived = mockAdapter.exposed_credit(frozenUser, TRANSFER_AMOUNT, 1);

        // Verify frozen transfer occurred
        assertEq(amountReceived, TRANSFER_AMOUNT, "Should return the full amount");
        assertEq(
            token.balanceOf(frozenUser),
            userBalanceBefore + TRANSFER_AMOUNT,
            "Frozen user balance should increase"
        );
        assertEq(
            token.balanceOf(address(mockAdapter)),
            adapterBalanceBefore - TRANSFER_AMOUNT,
            "Adapter balance should decrease"
        );
    }

    function test_credit_ZeroAddressBecomesDeadAddress() public {
        // Give the adapter some tokens to transfer
        vm.prank(minter);
        token.mint(address(mockAdapter), TRANSFER_AMOUNT);

        // Give dead address access (should use normal transfer)
        mockAccessRegistry.setAccess(address(0xdead), true);

        uint256 deadBalanceBefore = token.balanceOf(address(0xdead));
        uint256 adapterBalanceBefore = token.balanceOf(address(mockAdapter));

        // Call _credit with address(0) - should be converted to address(0xdead)
        uint256 amountReceived = mockAdapter.exposed_credit(address(0), TRANSFER_AMOUNT, 1);

        // Verify transfer went to dead address
        assertEq(amountReceived, TRANSFER_AMOUNT, "Should return the full amount");
        assertEq(
            token.balanceOf(address(0xdead)),
            deadBalanceBefore + TRANSFER_AMOUNT,
            "Dead address balance should increase"
        );
        assertEq(
            token.balanceOf(address(mockAdapter)),
            adapterBalanceBefore - TRANSFER_AMOUNT,
            "Adapter balance should decrease"
        );
    }

    function test_credit_ZeroAddressWithoutAccess_TransferToFrozen() public {
        // Give the adapter some tokens to transfer
        vm.prank(minter);
        token.mint(address(mockAdapter), TRANSFER_AMOUNT);

        // Don't give dead address access
        mockAccessRegistry.setAccess(address(0xdead), false);

        uint256 deadBalanceBefore = token.balanceOf(address(0xdead));

        // Expect the TransferredToFrozen event for dead address
        vm.expectEmit(true, true, false, true);
        emit TransferredToFrozen(address(mockAdapter), address(0xdead), TRANSFER_AMOUNT);

        // Call _credit with address(0) - should be converted to address(0xdead) and use transferToFrozen
        uint256 amountReceived = mockAdapter.exposed_credit(address(0), TRANSFER_AMOUNT, 1);

        // Verify frozen transfer occurred to dead address
        assertEq(amountReceived, TRANSFER_AMOUNT, "Should return the full amount");
        assertEq(
            token.balanceOf(address(0xdead)),
            deadBalanceBefore + TRANSFER_AMOUNT,
            "Dead address balance should increase"
        );
    }

    function test_credit_AccessChangeDuringOperation() public {
        // Give the adapter some tokens to transfer
        vm.prank(minter);
        token.mint(address(mockAdapter), TRANSFER_AMOUNT * 2);

        // First transfer: user has access
        mockAccessRegistry.setAccess(user1, true);
        uint256 amount1 = mockAdapter.exposed_credit(user1, TRANSFER_AMOUNT, 1);
        assertEq(amount1, TRANSFER_AMOUNT, "First transfer should succeed");

        // Change access and do second transfer
        mockAccessRegistry.setAccess(user1, false);

        vm.expectEmit(true, true, false, true);
        emit TransferredToFrozen(address(mockAdapter), user1, TRANSFER_AMOUNT);

        uint256 amount2 = mockAdapter.exposed_credit(user1, TRANSFER_AMOUNT, 1);
        assertEq(amount2, TRANSFER_AMOUNT, "Second transfer should use frozen method");
    }

    function test_credit_IgnoresSrcEidParameter() public {
        // Give the adapter some tokens to transfer
        vm.prank(minter);
        token.mint(address(mockAdapter), TRANSFER_AMOUNT * 3);
        mockAccessRegistry.setAccess(user1, true);

        uint256 balanceBefore = token.balanceOf(user1);

        // Test with different _srcEid values - should all work the same
        mockAdapter.exposed_credit(user1, 100e6, 1);
        mockAdapter.exposed_credit(user1, 100e6, 999);
        mockAdapter.exposed_credit(user1, 100e6, 0);

        // All transfers should have succeeded regardless of srcEid value
        assertEq(token.balanceOf(user1), balanceBefore + 300e6, "All transfers should succeed regardless of srcEid");
    }

    function testFuzz_credit_ValidAmounts(uint256 amount, bool hasAccess) public {
        // Limit to reasonable amounts to avoid overflow
        vm.assume(amount > 0 && amount <= 1e12 * 1e6); // Max 1 trillion tokens

        // Give the adapter enough tokens
        vm.prank(minter);
        token.mint(address(mockAdapter), amount);
        mockAccessRegistry.setAccess(user1, hasAccess);

        uint256 userBalanceBefore = token.balanceOf(user1);

        if (!hasAccess) {
            // Expect TransferredToFrozen event if user doesn't have access
            vm.expectEmit(true, true, false, true);
            emit TransferredToFrozen(address(mockAdapter), user1, amount);
        }

        // Call _credit function
        uint256 amountReceived = mockAdapter.exposed_credit(user1, amount, 1);

        // Verify results
        assertEq(amountReceived, amount, "Should return the full amount for any valid amount");
        assertEq(token.balanceOf(user1), userBalanceBefore + amount, "User balance should increase by the amount");
    }

    function testFuzz_credit_RandomAddresses(address randomUser) public {
        // Skip problematic addresses
        vm.assume(randomUser != address(0));
        vm.assume(randomUser != address(mockAdapter));
        vm.assume(randomUser.code.length == 0); // Skip contract addresses

        // Give the adapter some tokens
        vm.prank(minter);
        token.mint(address(mockAdapter), TRANSFER_AMOUNT);

        // Randomly give or don't give access
        bool hasAccess = uint256(uint160(randomUser)) % 2 == 0;
        mockAccessRegistry.setAccess(randomUser, hasAccess);

        uint256 userBalanceBefore = token.balanceOf(randomUser);

        // Call _credit function
        uint256 amountReceived = mockAdapter.exposed_credit(randomUser, TRANSFER_AMOUNT, 1);

        // Verify results
        assertEq(amountReceived, TRANSFER_AMOUNT, "Should work for any valid address");
        assertEq(token.balanceOf(randomUser), userBalanceBefore + TRANSFER_AMOUNT, "Balance should increase correctly");
    }

    function test_debit_RevertsForUserWithoutAccess() public {
        // Give user access to allow minting tokens to them
        mockAccessRegistry.setAccess(user1, true);
        vm.prank(minter);
        token.mint(user1, TRANSFER_AMOUNT);

        // Remove access from user1
        mockAccessRegistry.setAccess(user1, false);

        // Expect revert when trying to debit from user without access
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, user1));
        mockAdapter.exposed_debit(user1, TRANSFER_AMOUNT, TRANSFER_AMOUNT, 1);

        // Verify user still has tokens (debit failed)
        assertEq(token.balanceOf(user1), TRANSFER_AMOUNT, "User should still have tokens after failed debit");
    }
}
