// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.17;

import "src/interfaces/ILotteryToken.sol";

/// @dev Provided zero address for a lottery token
error LotteryTokenIsZeroAddress();

/// @dev Percentage rewards arrays are empty
error PercentageRewardsCannotBeZeroLength();

/// @dev The sum for the referrers and the players percentage rewards for the same index (period) is greater than 100%
///     (10_000)
error PercentageRewardsIsGreaterThanHundredPercent();

interface IReferralSystem {
    /// @dev Data about number of tickets user did not claim rewards for
    struct UnclaimedTicketsData {
        /// @dev Number of tickets sold as referrer for which rewards are unclaimed
        uint128 referrerTicketCount;
        /// @dev Number of tickets user has bought for which rewards are unclaimed
        uint128 playerTicketCount;
    }

    /// @dev Referrer with address @param referrer claimed amount @param claimedAmount for a draw @param drawId
    /// @param drawId Unique identifier for draw
    /// @param user The address of the referrer or player
    /// @param claimedAmount Claimed reward in the lotteryToken
    event ClaimedReferralReward(uint128 indexed drawId, address indexed user, uint256 indexed claimedAmount);

    /// @dev Reward amounts for referrers and players are calculated for draw with @param drawId
    /// @param drawId Unique identifier for draw
    /// @param referrerRewardForDraw Reward amount for referrers for draw with @param drawId
    /// @param playerRewardForDraw Reward amount for players for draw with @param drawId
    event CalculatedRewardsForDraw(
        uint128 indexed drawId, uint256 indexed referrerRewardForDraw, uint256 indexed playerRewardForDraw
    );

    /// @dev The setup for the percentage rewards for players per year
    function percentageRewardsToPlayers(uint256 index) external view returns (uint256);

    function unclaimedTickets(
        uint128 drawId,
        address user
    )
        external
        view
        returns (uint128 referrerTicketCount, uint128 playerTicketCount);

    /// @param drawId Unique identifier for draw
    /// @return totalNumberOfTickets The total number of tickets that are added for referrers for @param drawId
    function totalTicketsForReferrersPerDraw(uint128 drawId) external view returns (uint256 totalNumberOfTickets);

    /// @dev Referrer's rewards per draw for one ticket
    /// @param drawId Unique identifier for draw
    function referrerRewardPerDrawForOneTicket(uint128 drawId) external view returns (uint256 rewardsPerDraw);

    /// @dev Player's rewards per draw for one ticket
    /// @param drawId Unique identifier for draw
    function playerRewardsPerDrawForOneTicket(uint128 drawId) external view returns (uint256 rewardsPerDraw);

    /// @dev Claims both player and referrer reward if applicable
    /// @param drawIds List of draws reward is claimed for
    /// @return claimedReward Total amount claimed containing both player and referrer reward
    function claimReferralReward(uint128[] memory drawIds) external returns (uint256 claimedReward);

    /// @param drawId Unique identifier for draw
    /// @return minimumEligibleReferrals Calculate the minimum eligible referrals that are needed for the referrer to be
    /// rewarded
    function minimumEligibleReferrals(uint128 drawId) external view returns (uint256 minimumEligibleReferrals);
}
