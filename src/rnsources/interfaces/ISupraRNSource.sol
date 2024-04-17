// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ISupraRouter } from "src/rnsources/interfaces/external/ISupraRouter.sol";
import { IRNSource } from "src/rnsources/interfaces/IRNSource.sol";

interface ISupraRNSource is IRNSource {
    /// @dev Thrown when request confirmations is not between 1 to 20
    error RequestConfirmationsIsNotInScope(uint256 requestConfirmations);

    /// @dev Thrown when supraRouter not call callback function
    error SupraRouterIsNotMsgSender(uint256 requestId);

    /// @dev Thrown if a wrong count of random numbers is received
    /// @param requestId id of the request for random number
    /// @param numbersCount count of random numbers received for the request
    error WrongRandomNumberCountReceived(uint256 requestId, uint256 numbersCount);

    /// @return Address of the Supra router
    function supraRouter() external view returns (ISupraRouter);

    /// @return Client wallet address that is already registered with the Supra Team as input
    function clientWalletAddress() external view returns (address);

    /// @return minConfirmations Minimum number of confirmations before request can be fulfilled
    function requestConfirmations() external returns (uint8 minConfirmations);
}
