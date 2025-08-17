// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OFTAdapterUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";

import { IFrontierERC20F } from "./interfaces/IFrontierERC20F.sol";

/**
 * @title FrontierOFTAdapter
 * @author LayerZero Labs (@EWCunha)
 * @notice Adapter contract for wrapped Frontier token.
 */
contract FrontierOFTAdapter is OFTAdapterUpgradeable {
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
     * @dev Credits tokens to the specified address.
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     * @dev _srcEid The source chain ID.
     * @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
     */
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal virtual override returns (uint256 amountReceivedLD) {
        if (_to == address(0x0)) _to = address(0xdead); // _transfer(...) does not support address(0x0)

        IFrontierERC20F(token()).adapterTransfer(_to, _amountLD);

        return _amountLD;
    }
}
