// SPDX-LICENSE-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import { FrontierERC20F } from "../../contracts/FrontierERC20F.sol";
import { MockFrontierOFTAdapterMintAndBurn, FrontierOFTAdapterMintAndBurn } from "../mocks/MockFrontierOFTAdapterMintAndBurn.sol";
import { FrontierVault, IERC20Upgradeable } from "../../contracts/FrontierVault.sol";
import { FrontierOFTAdapter } from "../../contracts/FrontierOFTAdapter.sol";

import { IOFT, MessagingFee, MessagingReceipt, OFTReceipt, SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// @dev Pulling in EndpointV2 for lz-evm-protocol-v2 caused OZ dependency issues.
interface EndpointV2 {
    function delegates(address) external view returns (address);
}

// @dev Extends the OFTTest suite;  every OFT test should also pass for Fee implementations, albeit with any needed
// modifications for fees.
contract AdapterAndVaultIntegrationsTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;

    address public userA = address(0x1);
    address public userB = address(0x2);

    address public proxyAdmin = makeAddr("proxyAdmin");

    FrontierERC20F public token;
    FrontierVault public vaultToken;
    MockFrontierOFTAdapterMintAndBurn public maba;
    FrontierOFTAdapter public adapter;

    uint256 public INITIAL_BALANCE = 1000 ether;

    function setUp() public virtual override {
        // 1. deal out some ether to the users
        vm.deal(userA, INITIAL_BALANCE);
        vm.deal(userB, INITIAL_BALANCE);

        // 2. deploy the endpoints
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // 3. deploy the OFTs and OFTAdapter

        token = FrontierERC20F(
            _deployContractAndProxy(
                type(FrontierERC20F).creationCode,
                "",
                abi.encodeWithSelector(
                    FrontierERC20F.initialize.selector,
                    "TokenA",
                    "TKA",
                    address(this),
                    address(this),
                    address(this)
                )
            )
        );

        vaultToken = FrontierVault(
            _deployContractAndProxy(
                type(FrontierVault).creationCode,
                "",
                abi.encodeWithSignature(
                    "initialize(string,string,address,address,address,address)",
                    "Vault",
                    "vFRNT",
                    address(this),
                    address(this),
                    address(this),
                    IERC20Upgradeable(token)
                )
            )
        );

        adapter = FrontierOFTAdapter(
            _deployContractAndProxy(
                type(FrontierOFTAdapter).creationCode,
                abi.encode(address(vaultToken), address(endpoints[bEid])),
                abi.encodeWithSelector(FrontierOFTAdapter.initialize.selector, address(this))
            )
        );
        maba = MockFrontierOFTAdapterMintAndBurn(
            _deployContractAndProxy(
                type(MockFrontierOFTAdapterMintAndBurn).creationCode,
                abi.encode(address(token), address(endpoints[aEid])),
                abi.encodeWithSelector(FrontierOFTAdapterMintAndBurn.initialize.selector, address(this))
            )
        );

        // 4. config and wire the ofts
        address[] memory ofts = new address[](2);
        ofts[0] = address(adapter);
        ofts[1] = address(maba);
        this.wireOApps(ofts);

        // 5. mint OFT and ERC-20 tokens
        token.mint(userA, INITIAL_BALANCE);
        token.mint(userB, INITIAL_BALANCE);
        vaultToken.mint(userA, INITIAL_BALANCE);
        vaultToken.mint(userB, INITIAL_BALANCE);

        token.grantRole(token.ADAPTER_ROLE(), address(maba));

        vaultToken.grantRole(vaultToken.ADAPTER_ROLE(), address(adapter));
    }

    function _assumeDelegate(address _delegate) internal pure {
        vm.assume(_delegate != address(0));
    }

    function _deployContractAndProxy(
        bytes memory _oappBytecode,
        bytes memory _constructorArgs,
        bytes memory _initializeArgs
    ) internal returns (address addr) {
        bytes memory bytecode = bytes.concat(abi.encodePacked(_oappBytecode), _constructorArgs);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        return address(new TransparentUpgradeableProxy(addr, proxyAdmin, _initializeArgs));
    }

    function test_send_AdapterToMabaSuccess() public {
        uint256 amount = 1 ether;

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(aEid, addressToBytes32(userB), amount, amount, options, "", "");

        MessagingFee memory fee = adapter.quoteSend(sendParam, false);

        assertEq(vaultToken.balanceOf(userA), INITIAL_BALANCE);
        assertEq(token.balanceOf(userB), INITIAL_BALANCE);

        vm.startPrank(userA);
        vaultToken.approve(address(adapter), amount);
        adapter.send{ value: fee.nativeFee }(sendParam, fee, userA);
        vm.stopPrank();
        verifyPackets(aEid, addressToBytes32(address(maba)));

        assertEq(vaultToken.balanceOf(userA), INITIAL_BALANCE - amount);
        assertEq(token.balanceOf(userB), INITIAL_BALANCE + amount);
    }
}
