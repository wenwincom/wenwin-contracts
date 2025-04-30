// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "src/Lottery.sol";
import "src/interfaces/ILotteryNativeToken.sol";
import "src/interfaces/IWrappedNativeToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract LotteryNativeToken is Lottery, ReentrancyGuard, ILotteryNativeToken {
    using Address for address payable;

    constructor(
        LotterySetupParams memory lotterySetupParams,
        address feeRecipient_,
        uint256 maxRNRequestDelay,
        string memory baseURI
    )
        Lottery(lotterySetupParams, feeRecipient_, maxRNRequestDelay, baseURI)
    { }

    function buyTicketsWithNativeToken(
        uint128[] calldata drawIds,
        uint120[] calldata tickets,
        address frontend,
        address referrer
    )
        external
        payable
        nonReentrant
        returns (uint256[] memory ticketIds)
    {
        if (msg.value != ticketPrice * tickets.length) {
            revert InsufficientNativeToken();
        }
        IWrappedNativeToken(address(rewardToken)).deposit{ value: msg.value }();
        return buyTicketsAsDelegate(address(this), drawIds, tickets, frontend, referrer);
    }

    function claimWinningTicketsInNativeToken(uint256[] calldata ticketIds)
        external
        nonReentrant
        returns (uint256 claimedAmount)
    {
        claimedAmount = claimWinningTicketsAsDelegate(address(this), ticketIds);
        IWrappedNativeToken(address(rewardToken)).withdraw(claimedAmount);
        payable(msg.sender).sendValue(claimedAmount);
    }

    receive() external payable {
        require(msg.sender == address(rewardToken), "Only from the reward token");
    }

    fallback() external payable {
        require(msg.sender == address(rewardToken), "Only from the reward token");
    }
}
