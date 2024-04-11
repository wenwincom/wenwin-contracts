// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity ^0.8.19;

import { RrpRequesterV0 } from "@api3dao/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import { IAPI3DaoRNSource } from "src/rnsources/interfaces/IAPI3DaoRNSource.sol";
import { RNSourceBase } from "src/rnsources/RNSourceBase.sol";

contract API3DaoRNSource is IAPI3DaoRNSource, RNSourceBase, RrpRequesterV0 {
    address public immutable override airnodeProvider;

    bytes32 public immutable override endpointIdUint256;

    address public immutable override sponsorWallet;

    constructor(
        address _authorizedConsumer,
        address _airnodeRrp,
        address _airnodeProvider,
        bytes32 _endpointIdUint256,
        address _sponsorWallet
    )
        RNSourceBase(_authorizedConsumer)
        RrpRequesterV0(_airnodeRrp)
    {
        airnodeProvider = _airnodeProvider;
        endpointIdUint256 = _endpointIdUint256;
        sponsorWallet = _sponsorWallet;
    }

    /// @dev Assumes the contract is funded sufficiently
    function requestRandomnessFromUnderlyingSource() internal override returns (uint256 requestId) {
        requestId = uint256(
            airnodeRrp.makeFullRequest(
                airnodeProvider,
                endpointIdUint256,
                address(this),
                sponsorWallet,
                address(this),
                this.fulfillUint256.selector,
                ""
            )
        );
    }

    function fulfillUint256(bytes32 requestId, bytes calldata data) external onlyAirnodeRrp {
        uint256 qrngUint256 = abi.decode(data, (uint256));

        fulfill(uint256(requestId), qrngUint256);
    }
}
