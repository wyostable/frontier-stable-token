// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { FrontierOFTAdapterMintAndBurn } from "../../contracts/FrontierOFTAdapterMintAndBurn.sol";

/**
 * @title MockFrontierOFTAdapterMintAndBurn
 * @notice Concrete implementation to expose internal functions for testing
 */
contract MockFrontierOFTAdapterMintAndBurn is FrontierOFTAdapterMintAndBurn {
    constructor(address _token, address _lzEndpoint) FrontierOFTAdapterMintAndBurn(_token, _lzEndpoint) {}

    function exposed_debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) external returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        return _debit(_from, _amountLD, _minAmountLD, _dstEid);
    }

    function exposed_credit(address _to, uint256 _amountLD, uint32 _srcEid) external returns (uint256) {
        return _credit(_to, _amountLD, _srcEid);
    }
}
