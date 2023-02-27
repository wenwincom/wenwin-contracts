// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "src/LotteryToken.sol";
import "src/ReferralSystem.sol";

contract ReferralSystemConfig is Script {
    uint256 internal constant INITIAL_TOKEN_SUPPLY = 1_000_000_000e18;

    function getLotteryTokenAndRewardsPerc()
        internal
        returns (ILotteryToken lotteryToken, uint256[] memory percentageRewardsToPlayers)
    {
        lotteryToken = getLotteryToken();

        percentageRewardsToPlayers = new uint256[](3);
        percentageRewardsToPlayers[0] = 6250;
        percentageRewardsToPlayers[1] = 5000;
        percentageRewardsToPlayers[2] = 0;
    }

    function getLotteryToken() internal returns (ILotteryToken lotteryToken) {
        address lotteryTokenAddress = vm.envAddress("LOTTERY_TOKEN_ADDRESS");
        if (lotteryTokenAddress == address(0)) {
            uint256 firstYearInflation = 10; // 10%
            uint256 secondYearInflation = 5; // 5%
            uint256 thirdYearInflation = 2; // 2%

            uint256 tokenSupplyAfterFirstYear = (100 + firstYearInflation) * INITIAL_TOKEN_SUPPLY / 100;
            uint256 tokenSupplyAfterSecondYear = (100 + secondYearInflation) * tokenSupplyAfterFirstYear / 100;
            uint256 tokenSupplyAfterThirdYear = (100 + thirdYearInflation) * tokenSupplyAfterSecondYear / 100;

            uint256[] memory inflationRates = new uint256[](3);
            inflationRates[0] = (tokenSupplyAfterFirstYear - INITIAL_TOKEN_SUPPLY) / 52;
            inflationRates[1] = (tokenSupplyAfterSecondYear - tokenSupplyAfterFirstYear) / 52;
            inflationRates[2] = (tokenSupplyAfterThirdYear - tokenSupplyAfterSecondYear) / 52;
            lotteryToken = new LotteryToken(inflationRates);
        } else {
            lotteryToken = ILotteryToken(lotteryTokenAddress);
        }
    }
}
