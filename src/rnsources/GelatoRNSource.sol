// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity ^0.8.7;

import { GelatoVRFConsumerBase } from "./external/GelatoVRFConsumerBase.sol";
import { RNSourceBase } from "src/rnsources/RNSourceBase.sol";

contract GelatoRNSource is RNSourceBase, GelatoVRFConsumerBase {
    address private immutable OPERATOR;

    constructor(address authorizedConsumer_, address operator_) RNSourceBase(authorizedConsumer_) {
        OPERATOR = operator_;
    }

    function _operator() internal view override returns (address) {
        return OPERATOR;
    }

    function requestRandomnessFromUnderlyingSource() internal override returns (uint256 requestId) {
        requestId = _requestRandomness(abi.encode(""));
    }

    function _fulfillRandomness(uint256 randomness, uint256 requestId, bytes memory) internal override {
        fulfill(requestId, randomness);
    }
}
