// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "src/interfaces/ILottery.sol";

/// @dev Insufficient native token.
error InsufficientNativeToken();

interface ILotteryNativeToken is ILottery {
    /// @dev Buy set of tickets for the upcoming lotteries.
    /// `msg.sender` pays `ticketPrice` for each ticket and provides combination of numbers for each ticket.
    /// Reverts in case of invalid number combination in any of the tickets.
    /// Reverts in case of insufficient `msg.value`(`tickets.length * ticketPrice`) in `msg.sender`'s account.
    /// @param drawIds Draw identifiers user buys ticket for.
    /// @param tickets list of uint120 packed tickets. Needs to be of same length as `drawIds`.
    /// @param frontend Address of a frontend operator selling the ticket.
    /// @param referrer The address of a referrer.
    /// @return ticketIds List of minted ticket identifiers.
    function buyTicketsWithNativeToken(
        uint128[] calldata drawIds,
        uint120[] calldata tickets,
        address frontend,
        address referrer
    )
        external
        payable
        returns (uint256[] memory ticketIds);

    /// @dev Transfer all winnings to `msg.sender` for the winning tickets.
    /// It reverts in case of non winning ticket.
    /// Only ticket owner can claim win, if any of the tickets is not owned by `msg.sender` it will revert.
    /// @param ticketIds List of ids of the tickets being claimed.
    /// @return claimedAmount Amount of native token claimed to `msg.sender`.
    function claimWinningTicketsInNativeToken(uint256[] calldata ticketIds) external returns (uint256 claimedAmount);
}
