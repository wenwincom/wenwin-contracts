// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ISupraRouter } from "src/rnsources/interfaces/external/ISupraRouter.sol";
import { ISupraRNSource } from "src/rnsources/interfaces/ISupraRNSource.sol";
import { RNSourceBase } from "src/rnsources/RNSourceBase.sol";

contract SupraRNSource is RNSourceBase, ISupraRNSource {
    ISupraRouter public immutable override supraRouter;
    address public immutable override clientWalletAddress;
    uint8 public immutable override requestConfirmations;

    constructor(
        address _authorizedConsumer,
        address _supraRouter,
        address _clientWalletAddress,
        uint8 _requestConfirmations
    )
        RNSourceBase(_authorizedConsumer)
    {
        supraRouter = ISupraRouter(_supraRouter);
        clientWalletAddress = _clientWalletAddress;
        requestConfirmations = _requestConfirmations;
    }

    /// @dev Assumes the contract is funded sufficiently
    function requestRandomnessFromUnderlyingSource() internal override returns (uint256 requestId) {
        //Requesting 1 random numbers
        uint8 rngCount = 1;

        requestId = supraRouter.generateRequest(
            "fulfill(uint256,uint256[])", rngCount, requestConfirmations, clientWalletAddress
        );
    }

    function fulfill(uint256 _requestId, uint256[] memory _rngList) external {
        if (msg.sender != address(supraRouter)) {
            revert SupraRouterIsNotMsgSender(_requestId);
        }

        if (_rngList.length != 1) {
            revert WrongRandomNumberCountReceived(_requestId, _rngList.length);
        }

        fulfill(_requestId, _rngList[0]);
    }
}
