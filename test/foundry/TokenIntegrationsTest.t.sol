// SPDX-LICENSE-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import { FrontierERC20F } from "../../contracts/FrontierERC20F.sol";
import { MockFrontierOFTAdapterMintAndBurn, FrontierOFTAdapterMintAndBurn } from "../mocks/MockFrontierOFTAdapterMintAndBurn.sol";

import { IOFT, MessagingFee, MessagingReceipt, OFTReceipt, SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// @dev Pulling in EndpointV2 for lz-evm-protocol-v2 caused OZ dependency issues.
interface EndpointV2 {
    function delegates(address) external view returns (address);
}

contract TokenIntegrationsTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;

    address public userA = address(0x1);
    address public userB = address(0x2);

    address public proxyAdmin = makeAddr("proxyAdmin");

    FrontierERC20F public tokenA;
    FrontierERC20F public tokenB;
    MockFrontierOFTAdapterMintAndBurn public adapterA;
    MockFrontierOFTAdapterMintAndBurn public adapterB;

    uint256 public INITIAL_BALANCE = 1000 ether;

    function setUp() public virtual override {
        // 1. deal out some ether to the users
        vm.deal(userA, INITIAL_BALANCE);
        vm.deal(userB, INITIAL_BALANCE);

        // 2. deploy the endpoints
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // 3. deploy the OFTs and OFTAdapter

        tokenA = FrontierERC20F(
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
        tokenB = FrontierERC20F(
            _deployContractAndProxy(
                type(FrontierERC20F).creationCode,
                "",
                abi.encodeWithSelector(
                    FrontierERC20F.initialize.selector,
                    "TokenB",
                    "TKB",
                    address(this),
                    address(this),
                    address(this)
                )
            )
        );
        adapterA = MockFrontierOFTAdapterMintAndBurn(
            _deployContractAndProxy(
                type(MockFrontierOFTAdapterMintAndBurn).creationCode,
                abi.encode(address(tokenA), address(endpoints[aEid])),
                abi.encodeWithSelector(FrontierOFTAdapterMintAndBurn.initialize.selector, address(this))
            )
        );
        adapterB = MockFrontierOFTAdapterMintAndBurn(
            _deployContractAndProxy(
                type(MockFrontierOFTAdapterMintAndBurn).creationCode,
                abi.encode(address(tokenB), address(endpoints[bEid])),
                abi.encodeWithSelector(FrontierOFTAdapterMintAndBurn.initialize.selector, address(this))
            )
        );

        // 4. config and wire the ofts
        address[] memory ofts = new address[](2);
        ofts[0] = address(adapterA);
        ofts[1] = address(adapterB);
        this.wireOApps(ofts);

        // 5. mint OFT and ERC-20 tokens
        tokenA.mint(userA, INITIAL_BALANCE);
        tokenB.mint(userB, INITIAL_BALANCE);

        tokenA.grantRole(tokenA.ADAPTER_ROLE(), address(adapterA));
        tokenB.grantRole(tokenB.ADAPTER_ROLE(), address(adapterB));
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

    function test_send_Success() public {
        uint256 amount = 1 ether;

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(bEid, addressToBytes32(userB), amount, amount, options, "", "");

        MessagingFee memory fee = adapterA.quoteSend(sendParam, false);

        assertEq(tokenA.balanceOf(userA), INITIAL_BALANCE);
        assertEq(tokenB.balanceOf(userB), INITIAL_BALANCE);

        vm.prank(userA);
        adapterA.send{ value: fee.nativeFee }(sendParam, fee, userA);
        verifyPackets(bEid, addressToBytes32(address(adapterB)));

        assertEq(tokenA.balanceOf(userA), INITIAL_BALANCE - amount);
        assertEq(tokenB.balanceOf(userB), INITIAL_BALANCE + amount);
    }
}
