// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "src/LotteryToken.sol";
import "src/ReferralSystem.sol";

contract ReferralSystemConfig is Script {
    uint256 internal constant INITIAL_TOKEN_SUPPLY = 1_000_000_000e18;

    function getLotteryRewardsData()
        internal
        pure
        returns (uint256[] memory inflationRates, uint256[] memory percentageRewardsToPlayers)
    {
        uint256 firstYearInflation = 10; // 10%
        uint256 secondYearInflation = 5; // 5%
        uint256 thirdYearInflation = 2; // 2%

        uint256 tokenSupplyAfterFirstYear = (100 + firstYearInflation) * INITIAL_TOKEN_SUPPLY / 100;
        uint256 tokenSupplyAfterSecondYear = (100 + secondYearInflation) * tokenSupplyAfterFirstYear / 100;
        uint256 tokenSupplyAfterThirdYear = (100 + thirdYearInflation) * tokenSupplyAfterSecondYear / 100;

        inflationRates = new uint256[](3 * 52);
        inflationRates[0] = (tokenSupplyAfterFirstYear - INITIAL_TOKEN_SUPPLY) / 52;
        inflationRates[52] = (tokenSupplyAfterSecondYear - tokenSupplyAfterFirstYear) / 52;
        inflationRates[104] = (tokenSupplyAfterThirdYear - tokenSupplyAfterSecondYear) / 52;
        for (uint256 i = 1; i < 3 * 52; i++) {
            if (i % 52 != 0) {
                inflationRates[i] = inflationRates[i - 1];
            }
        }

        percentageRewardsToPlayers = new uint256[](104);
        percentageRewardsToPlayers[0] = 6250;
        percentageRewardsToPlayers[52] = 5000;
        percentageRewardsToPlayers[104] = 0;
        for (uint256 i = 1; i < 104; i++) {
            if (i % 52 != 0) {
                percentageRewardsToPlayers[i] = percentageRewardsToPlayers[i - 1];
            }
        }
    }
}
