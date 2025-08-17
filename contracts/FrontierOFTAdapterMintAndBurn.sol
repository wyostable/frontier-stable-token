// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OFTAdapterUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";

import { IFrontierERC20F } from "./interfaces/IFrontierERC20F.sol";

/**
 * @title FrontierOFTAdapterMintAndBurn
 * @author LayerZero Labs (@EWCunha)
 * @notice Mint and Burn OFT adapter with upgradeable logic.
 */
contract FrontierOFTAdapterMintAndBurn is OFTAdapterUpgradeable {
    /**
     * @dev Constructor for initializing the contract with token and endpoint addresses.
     * @param _token The address of the token.
     * @param _lzEndpoint The address of the LayerZero endpoint.
     */
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _delegate The address of the delegate.
     */
    function initialize(address _delegate) external initializer {
        __OFTAdapter_init(_delegate);
        __Ownable_init(_delegate);
    }

    /**
     * @notice Indicates whether the OFT contract requires approval of the underlying token to send.
     * @return requiresApproval True if approval is required, false otherwise.
     *
     * @dev In this MintBurnOFTAdapter, approval is NOT required because it uses mint and burn privileges.
     */
    function approvalRequired() external pure override returns (bool) {
        return false;
    }

    /**
     * @notice Burns tokens from the sender's balance to prepare for sending.
     * @param _from The address to debit the tokens from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        IFrontierERC20F(token()).adapterBurn(_from, amountSentLD);
    }

    /**
     * @dev Credits tokens to the specified address.
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     * @dev _srcEid The source chain ID.
     * @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
     */
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /* _srcEid */
    ) internal virtual override returns (uint256 amountReceivedLD) {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)

        IFrontierERC20F(token()).adapterMint(_to, _amountLD);

        return _amountLD;
    }
}
