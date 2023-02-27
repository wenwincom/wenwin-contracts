// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.17;

import "src/interfaces/ILotteryToken.sol";
import "src/interfaces/IReferralSystem.sol";
import "src/LotteryMath.sol";

abstract contract ReferralSystem is IReferralSystem {
    uint256 internal constant PERCENTAGE_BASE = 10_000;

    ILotteryToken public immutable override lotteryToken;

    uint256[] public override percentageRewardsToPlayers;

    mapping(uint128 => mapping(address => UnclaimedTicketsData)) public override unclaimedTickets;

    mapping(uint128 => uint256) public override totalTicketsForReferrersPerDraw;

    mapping(uint128 => uint256) public override referrerRewardPerDrawForOneTicket;

    mapping(uint128 => uint256) public override playerRewardsPerDrawForOneTicket;

    mapping(uint128 => uint256) public override minimumEligibleReferrals;

    constructor(ILotteryToken _lotteryToken, uint256[] memory _percentageRewardsToPlayers) {
        if (address(_lotteryToken) == address(0)) {
            revert LotteryTokenIsZeroAddress();
        }
        uint256 percentageRewardsToPlayersLength = _percentageRewardsToPlayers.length;

        if (percentageRewardsToPlayersLength == 0) {
            revert PercentageRewardsCannotBeZeroLength();
        }

        for (uint256 counter = 0; counter < percentageRewardsToPlayersLength; ++counter) {
            if (_percentageRewardsToPlayers[counter] > PERCENTAGE_BASE) {
                revert PercentageRewardsIsGreaterThanHundredPercent();
            }
        }

        lotteryToken = _lotteryToken;
        percentageRewardsToPlayers = _percentageRewardsToPlayers;
    }

    /// @dev Registers tickets for player and referrer (if an address is not zero)
    /// @param currentDraw Currently active draw
    /// @param referrer The address of the referrer
    /// @param player The address of the player
    /// @param numberOfTickets Number of tickets we are registering
    function referralRegisterTickets(
        uint128 currentDraw,
        address referrer,
        address player,
        uint256 numberOfTickets
    )
        internal
    {
        if (referrer != address(0)) {
            uint256 minimumEligible = minimumEligibleReferrals[currentDraw];
            if (unclaimedTickets[currentDraw][referrer].referrerTicketCount + numberOfTickets >= minimumEligible) {
                if (unclaimedTickets[currentDraw][referrer].referrerTicketCount < minimumEligible) {
                    totalTicketsForReferrersPerDraw[currentDraw] +=
                        unclaimedTickets[currentDraw][referrer].referrerTicketCount;
                }
                totalTicketsForReferrersPerDraw[currentDraw] += numberOfTickets;
            }
            unclaimedTickets[currentDraw][referrer].referrerTicketCount += uint128(numberOfTickets);
        }
        unclaimedTickets[currentDraw][player].playerTicketCount += uint128(numberOfTickets);
    }

    function claimReferralReward(uint128[] memory drawIds) external override returns (uint256 claimedReward) {
        for (uint256 counter = 0; counter < drawIds.length; ++counter) {
            claimedReward += claimPerDraw(drawIds[counter]);
        }

        lotteryToken.mint(msg.sender, claimedReward);
    }

    /// @dev Draw is being finalized, does the rewards calculations for the draw
    /// @param drawFinalized Draw being finalized
    /// @param ticketsSoldDuringDraw Number of tickets sold during the draw that is finalized
    function referralDrawFinalize(uint128 drawFinalized, uint256 ticketsSoldDuringDraw) internal {
        // if no tickets sold there is no incentives, so no rewards to be set
        if (ticketsSoldDuringDraw == 0) {
            return;
        }
        uint256 mintableAmount = lotteryToken.checkMintableAndIncreaseNextDraw();

        uint256 indexForDraw = LotteryMath.inflationRateIndexForDraw(drawFinalized, percentageRewardsToPlayers.length);
        uint256 percentageRewardToPlayers = percentageRewardsToPlayers[indexForDraw];
        uint256 playerRewardForDraw = mintableAmount * percentageRewardToPlayers / PERCENTAGE_BASE;
        uint256 referrerRewardForDraw = mintableAmount - playerRewardForDraw;

        uint256 totalTicketsForReferrersPerCurrentDraw = totalTicketsForReferrersPerDraw[drawFinalized];
        if (totalTicketsForReferrersPerCurrentDraw > 0) {
            referrerRewardPerDrawForOneTicket[drawFinalized] =
                referrerRewardForDraw / totalTicketsForReferrersPerCurrentDraw;
        }
        playerRewardsPerDrawForOneTicket[drawFinalized] = playerRewardForDraw / ticketsSoldDuringDraw;
        minimumEligibleReferrals[drawFinalized + 1] =
            getMinimumEligibleReferralsFactorCalculation(ticketsSoldDuringDraw);

        emit CalculatedRewardsForDraw(drawFinalized, referrerRewardForDraw, playerRewardForDraw);
    }

    function getMinimumEligibleReferralsFactorCalculation(uint256 totalTicketsSoldPrevDraw)
        internal
        view
        virtual
        returns (uint256 minimumEligible)
    {
        if (totalTicketsSoldPrevDraw < 10_000) {
            return 100 * totalTicketsSoldPrevDraw / PERCENTAGE_BASE;
        }
        if (totalTicketsSoldPrevDraw < 100_000) {
            return 75 * totalTicketsSoldPrevDraw / PERCENTAGE_BASE;
        }
        if (totalTicketsSoldPrevDraw < 1_000_000) {
            return 50 * totalTicketsSoldPrevDraw / PERCENTAGE_BASE;
        }
        return 5000;
    }

    /// @dev Reverts if draw is not yet finalized
    /// @param drawId Draw identifier we are checking
    function requireFinishedDraw(uint128 drawId) internal view virtual;

    function claimPerDraw(uint128 drawId) private returns (uint256 claimedReward) {
        requireFinishedDraw(drawId);

        UnclaimedTicketsData memory _unclaimedTickets = unclaimedTickets[drawId][msg.sender];
        if (_unclaimedTickets.referrerTicketCount >= minimumEligibleReferrals[drawId]) {
            claimedReward = referrerRewardPerDrawForOneTicket[drawId] * _unclaimedTickets.referrerTicketCount;
            unclaimedTickets[drawId][msg.sender].referrerTicketCount = 0;
        }

        _unclaimedTickets = unclaimedTickets[drawId][msg.sender];
        if (_unclaimedTickets.playerTicketCount > 0) {
            claimedReward += playerRewardsPerDrawForOneTicket[drawId] * _unclaimedTickets.playerTicketCount;
            unclaimedTickets[drawId][msg.sender].playerTicketCount = 0;
        }

        if (claimedReward > 0) {
            emit ClaimedReferralReward(drawId, msg.sender, claimedReward);
        }
    }
}
