// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { FrontierOFTAdapter } from "../../contracts/FrontierOFTAdapter.sol";

/**
 * @title MockFrontierOFTAdapter
 * @notice Wrapper contract to expose internal _credit function for testing
 */
contract MockFrontierOFTAdapter is FrontierOFTAdapter {
    constructor(address _token, address _lzEndpoint) FrontierOFTAdapter(_token, _lzEndpoint) {}

    function exposed_credit(address _to, uint256 _amountLD, uint32 _srcEid) external returns (uint256) {
        return _credit(_to, _amountLD, _srcEid);
    }

    function exposed_debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) external returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        return _debit(_from, _amountLD, _minAmountLD, _dstEid);
    }
}
