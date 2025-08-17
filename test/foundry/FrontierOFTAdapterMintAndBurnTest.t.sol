// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { FrontierOFTAdapterMintAndBurn } from "../../contracts/FrontierOFTAdapterMintAndBurn.sol";
import { FrontierERC20F } from "../../contracts/FrontierERC20F.sol";
import { IFrontierERC20F } from "../../contracts/interfaces/IFrontierERC20F.sol";
import { IERC20Errors } from "../../contracts/fireblocks/library/interface/IERC20Errors.sol";

import { MockAccessRegistry } from "../mocks/MockAccessRegistry.sol";
import { MockLayerZeroEndpoint } from "../mocks/MockLayerZeroEndpoint.sol";
import { MockFrontierOFTAdapterMintAndBurn } from "../mocks/MockFrontierOFTAdapterMintAndBurn.sol";

contract FrontierOFTAdapterMintAndBurnTest is Test {
    FrontierOFTAdapterMintAndBurn public adapter;
    MockFrontierOFTAdapterMintAndBurn public mockAdapter;
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

    event MintedToFrozen(address indexed caller, address indexed to, uint256 amount);

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

        // Deploy mock adapter through proxy for proper initialization
        MockFrontierOFTAdapterMintAndBurn mockImplementation = new MockFrontierOFTAdapterMintAndBurn(
            address(token),
            address(mockEndpoint)
        );
        bytes memory initData = abi.encodeWithSelector(FrontierOFTAdapterMintAndBurn.initialize.selector, delegate);
        ERC1967Proxy mockProxy = new ERC1967Proxy(address(mockImplementation), initData);
        mockAdapter = MockFrontierOFTAdapterMintAndBurn(address(mockProxy));

        // Setup roles and access registry
        vm.startPrank(defaultAdmin);
        token.grantRole(token.CONTRACT_ADMIN_ROLE(), defaultAdmin);
        token.grantRole(token.ADAPTER_ROLE(), address(mockAdapter));
        token.accessRegistryUpdate(address(mockAccessRegistry));
        vm.stopPrank();

        // Grant access to the mockAdapter so it can receive tokens
        mockAccessRegistry.setAccess(address(mockAdapter), true);
    }

    function testMockAdapter() public view {
        assertEq(address(mockAdapter.token()), address(token), "Mock adapter should have correct token");
    }

    function test_constructor_SetsTokenAndEndpoint() public {
        // Create a new adapter to test constructor
        MockFrontierOFTAdapterMintAndBurn newAdapter = new MockFrontierOFTAdapterMintAndBurn(
            address(token),
            address(mockEndpoint)
        );

        // Verify the token is set correctly
        assertEq(address(newAdapter.token()), address(token), "Token should be set correctly in constructor");
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

        MockFrontierOFTAdapterMintAndBurn newAdapter = new MockFrontierOFTAdapterMintAndBurn(
            address(anotherToken),
            address(mockEndpoint)
        );

        assertEq(address(newAdapter.token()), address(anotherToken), "Should work with different tokens");
        assertNotEq(address(newAdapter.token()), address(token), "Should be different from original token");
    }

    function test_constructor_DisablesInitializers() public {
        // Create a new implementation
        MockFrontierOFTAdapterMintAndBurn implementation = new MockFrontierOFTAdapterMintAndBurn(
            address(token),
            address(mockEndpoint)
        );

        // Attempting to initialize the implementation directly should revert
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        implementation.initialize(delegate);
    }

    function test_initialize_Success() public {
        // Deploy implementation
        MockFrontierOFTAdapterMintAndBurn implementation = new MockFrontierOFTAdapterMintAndBurn(
            address(token),
            address(mockEndpoint)
        );

        bytes memory initData = abi.encodeWithSelector(FrontierOFTAdapterMintAndBurn.initialize.selector, delegate);

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        FrontierOFTAdapterMintAndBurn proxyAdapter = FrontierOFTAdapterMintAndBurn(address(proxy));

        // Verify initialization was successful
        assertEq(proxyAdapter.owner(), delegate, "Delegate should be set as owner");
    }

    function test_initialize_CannotInitializeTwice() public {
        // Deploy and initialize adapter through proxy
        MockFrontierOFTAdapterMintAndBurn implementation = new MockFrontierOFTAdapterMintAndBurn(
            address(token),
            address(mockEndpoint)
        );
        bytes memory initData = abi.encodeWithSelector(FrontierOFTAdapterMintAndBurn.initialize.selector, delegate);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        FrontierOFTAdapterMintAndBurn proxyAdapter = FrontierOFTAdapterMintAndBurn(address(proxy));

        // Attempting to initialize again should revert
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        proxyAdapter.initialize(delegate);
    }

    function test_initialize_DifferentDelegates() public {
        address delegate1 = makeAddr("delegate1");
        address delegate2 = makeAddr("delegate2");

        // Test with delegate1
        MockFrontierOFTAdapterMintAndBurn implementation1 = new MockFrontierOFTAdapterMintAndBurn(
            address(token),
            address(mockEndpoint)
        );
        bytes memory initData1 = abi.encodeWithSelector(FrontierOFTAdapterMintAndBurn.initialize.selector, delegate1);
        ERC1967Proxy proxy1 = new ERC1967Proxy(address(implementation1), initData1);
        FrontierOFTAdapterMintAndBurn adapter1 = FrontierOFTAdapterMintAndBurn(address(proxy1));

        // Test with delegate2
        MockFrontierOFTAdapterMintAndBurn implementation2 = new MockFrontierOFTAdapterMintAndBurn(
            address(token),
            address(mockEndpoint)
        );
        bytes memory initData2 = abi.encodeWithSelector(FrontierOFTAdapterMintAndBurn.initialize.selector, delegate2);
        ERC1967Proxy proxy2 = new ERC1967Proxy(address(implementation2), initData2);
        FrontierOFTAdapterMintAndBurn adapter2 = FrontierOFTAdapterMintAndBurn(address(proxy2));

        assertEq(adapter1.owner(), delegate1, "First adapter should have delegate1");
        assertEq(adapter2.owner(), delegate2, "Second adapter should have delegate2");
    }

    function test_approvalRequired_ReturnsFalse() public view {
        assertFalse(mockAdapter.approvalRequired(), "Approval should not be required for mint and burn adapter");
    }

    function test_debit_BurnsTokensFromSender() public {
        // Give user1 access first, then mint tokens
        mockAccessRegistry.setAccess(user1, true);
        vm.prank(minter);
        token.mint(user1, TRANSFER_AMOUNT);

        uint256 userBalanceBefore = token.balanceOf(user1);

        // Call the exposed _debit function
        (uint256 amountSentLD, uint256 amountReceivedLD) = mockAdapter.exposed_debit(
            user1,
            TRANSFER_AMOUNT,
            TRANSFER_AMOUNT,
            1
        );

        // Verify tokens were burned
        assertEq(amountSentLD, TRANSFER_AMOUNT, "Should return the full amount sent");
        assertEq(amountReceivedLD, TRANSFER_AMOUNT, "Should return the full amount received");
        assertEq(token.balanceOf(user1), userBalanceBefore - TRANSFER_AMOUNT, "User balance should decrease");
    }

    function test_debit_HandlesMinimumAmount() public {
        // Give user1 access first, then mint tokens
        mockAccessRegistry.setAccess(user1, true);
        vm.prank(minter);
        token.mint(user1, TRANSFER_AMOUNT);

        uint256 minAmount = TRANSFER_AMOUNT / 2;

        // Call the exposed _debit function with minimum amount
        (uint256 amountSentLD, uint256 amountReceivedLD) = mockAdapter.exposed_debit(
            user1,
            TRANSFER_AMOUNT,
            minAmount,
            1
        );

        // Verify correct amounts
        assertEq(amountSentLD, TRANSFER_AMOUNT, "Should return the full amount sent");
        assertEq(amountReceivedLD, TRANSFER_AMOUNT, "Should return the full amount received");
        assertGe(amountSentLD, minAmount, "Amount sent should be at least minimum");
    }

    function test_debit_RevertsForUserWithoutAccess() public {
        // Give user access to mint tokens, then remove access
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

    function test_credit_UserWithAccess_NormalMint() public {
        // Give user1 access
        mockAccessRegistry.setAccess(user1, true);

        uint256 userBalanceBefore = token.balanceOf(user1);

        // Call the exposed _credit function
        uint256 amountReceived = mockAdapter.exposed_credit(user1, TRANSFER_AMOUNT, 1);

        // Verify normal mint occurred
        assertEq(amountReceived, TRANSFER_AMOUNT, "Should return the full amount");
        assertEq(token.balanceOf(user1), userBalanceBefore + TRANSFER_AMOUNT, "User balance should increase");
    }

    function test_credit_UserWithoutAccess_MintToFrozen() public {
        // Don't give frozenUser access (default is false)
        mockAccessRegistry.setAccess(frozenUser, false);

        uint256 userBalanceBefore = token.balanceOf(frozenUser);

        // Expect the MintedToFrozen event
        vm.expectEmit(true, true, false, true);
        emit MintedToFrozen(address(mockAdapter), frozenUser, TRANSFER_AMOUNT);

        // Call the exposed _credit function
        uint256 amountReceived = mockAdapter.exposed_credit(frozenUser, TRANSFER_AMOUNT, 1);

        // Verify frozen mint occurred
        assertEq(amountReceived, TRANSFER_AMOUNT, "Should return the full amount");
        assertEq(
            token.balanceOf(frozenUser),
            userBalanceBefore + TRANSFER_AMOUNT,
            "Frozen user balance should increase"
        );
    }

    function test_credit_ZeroAddressBecomesDeadAddress() public {
        // Give dead address access (should use normal mint)
        mockAccessRegistry.setAccess(address(0xdead), true);

        uint256 deadBalanceBefore = token.balanceOf(address(0xdead));

        // Call _credit with address(0) - should be converted to address(0xdead)
        uint256 amountReceived = mockAdapter.exposed_credit(address(0), TRANSFER_AMOUNT, 1);

        // Verify mint went to dead address
        assertEq(amountReceived, TRANSFER_AMOUNT, "Should return the full amount");
        assertEq(
            token.balanceOf(address(0xdead)),
            deadBalanceBefore + TRANSFER_AMOUNT,
            "Dead address balance should increase"
        );
    }

    function test_credit_ZeroAddressWithoutAccess_MintToFrozen() public {
        // Don't give dead address access
        mockAccessRegistry.setAccess(address(0xdead), false);

        uint256 deadBalanceBefore = token.balanceOf(address(0xdead));

        // Expect the MintedToFrozen event for dead address
        vm.expectEmit(true, true, false, true);
        emit MintedToFrozen(address(mockAdapter), address(0xdead), TRANSFER_AMOUNT);

        // Call _credit with address(0) - should be converted to address(0xdead) and use mintToFrozen
        uint256 amountReceived = mockAdapter.exposed_credit(address(0), TRANSFER_AMOUNT, 1);

        // Verify frozen mint occurred to dead address
        assertEq(amountReceived, TRANSFER_AMOUNT, "Should return the full amount");
        assertEq(
            token.balanceOf(address(0xdead)),
            deadBalanceBefore + TRANSFER_AMOUNT,
            "Dead address balance should increase"
        );
    }

    function test_credit_AccessChangeDuringOperation() public {
        // First credit: user has access
        mockAccessRegistry.setAccess(user1, true);
        uint256 amount1 = mockAdapter.exposed_credit(user1, TRANSFER_AMOUNT, 1);
        assertEq(amount1, TRANSFER_AMOUNT, "First credit should succeed");

        // Change access and do second credit
        mockAccessRegistry.setAccess(user1, false);

        vm.expectEmit(true, true, false, true);
        emit MintedToFrozen(address(mockAdapter), user1, TRANSFER_AMOUNT);

        uint256 amount2 = mockAdapter.exposed_credit(user1, TRANSFER_AMOUNT, 1);
        assertEq(amount2, TRANSFER_AMOUNT, "Second credit should use frozen method");
    }

    function test_credit_IgnoresSrcEidParameter() public {
        mockAccessRegistry.setAccess(user1, true);

        uint256 balanceBefore = token.balanceOf(user1);

        // Test with different _srcEid values - should all work the same
        mockAdapter.exposed_credit(user1, 100e6, 1);
        mockAdapter.exposed_credit(user1, 100e6, 999);
        mockAdapter.exposed_credit(user1, 100e6, 0);

        // All credits should have succeeded regardless of srcEid value
        assertEq(token.balanceOf(user1), balanceBefore + 300e6, "All credits should succeed regardless of srcEid");
    }

    function testFuzz_credit_ValidAmounts(uint256 amount, bool hasAccess) public {
        // Limit to reasonable amounts to avoid overflow
        vm.assume(amount > 0 && amount <= 1e12 * 1e6); // Max 1 trillion tokens

        mockAccessRegistry.setAccess(user1, hasAccess);

        uint256 userBalanceBefore = token.balanceOf(user1);

        if (!hasAccess) {
            // Expect MintedToFrozen event if user doesn't have access
            vm.expectEmit(true, true, false, true);
            emit MintedToFrozen(address(mockAdapter), user1, amount);
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

    function testFuzz_debit_ValidAmounts(uint256 amount) public {
        // Limit to reasonable amounts to avoid overflow
        vm.assume(amount > 0 && amount <= 1e12 * 1e6); // Max 1 trillion tokens

        // Give user1 access first, then mint enough tokens to burn
        mockAccessRegistry.setAccess(user1, true);
        vm.prank(minter);
        token.mint(user1, amount);

        uint256 userBalanceBefore = token.balanceOf(user1);

        // Call _debit function
        (uint256 amountSentLD, uint256 amountReceivedLD) = mockAdapter.exposed_debit(user1, amount, amount, 1);

        // Verify results
        assertEq(amountSentLD, amount, "Should return the full amount sent");
        assertEq(amountReceivedLD, amount, "Should return the full amount received");
        assertEq(token.balanceOf(user1), userBalanceBefore - amount, "User balance should decrease by the amount");
    }
}
