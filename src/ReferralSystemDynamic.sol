// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.17;

import "src/interfaces/IReferralSystemDynamic.sol";
import "src/ReferralSystem.sol";

abstract contract ReferralSystemDynamic is IReferralSystemDynamic, ReferralSystem {
    MinimumReferralsRequirement[] public override referralRequirements;

    constructor(
        ILotteryToken _lotteryToken,
        uint256[] memory _percentageRewardsToPlayers,
        MinimumReferralsRequirement[] memory _referralRequirements
    )
        ReferralSystem(_lotteryToken, _percentageRewardsToPlayers)
    {
        if (_referralRequirements[0].minimumTicketsSold > 0) {
            revert MinimumTicketsSoldAtFirstIndexNotZero();
        }

        for (uint256 counter = 0; counter < _referralRequirements.length; ++counter) {
            if (
                counter > 0
                    && _referralRequirements[counter].minimumTicketsSold
                        <= _referralRequirements[counter - 1].minimumTicketsSold
            ) {
                revert MinimumTicketsSoldNotGreaterThanPrevious();
            }
            referralRequirements.push(_referralRequirements[counter]);
        }
        minimumEligibleReferrals[0] = getMinimumEligibleReferralsFactorCalculation(0);
    }

    function getMinimumEligibleReferralsFactorCalculation(uint256 totalTicketsSoldPrevDraw)
        internal
        view
        override
        returns (uint256 minimumEligible)
    {
        uint256 referralRequirementIndex = 0;
        for (; referralRequirementIndex < referralRequirements.length; ++referralRequirementIndex) {
            if (totalTicketsSoldPrevDraw < referralRequirements[referralRequirementIndex].minimumTicketsSold) {
                break;
            }
        }

        MinimumReferralsRequirement memory referralRequirement = referralRequirements[referralRequirementIndex - 1];
        if (referralRequirement.factorType == ReferralRequirementFactorType.PERCENT) {
            minimumEligible = totalTicketsSoldPrevDraw * referralRequirement.factor / PERCENTAGE_BASE;
        } else if (referralRequirement.factorType == ReferralRequirementFactorType.FIXED) {
            minimumEligible = referralRequirement.factor;
        }
    }
}
