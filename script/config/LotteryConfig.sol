// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "src/interfaces/IReferralSystem.sol";
import "src/interfaces/IRNSourceController.sol";
import "src/Lottery.sol";

contract LotteryConfig is Script {
    function getLottery(
        IERC20 rewardToken,
        uint256[] memory inflationPerDraw,
        uint256[] memory percentageRewardsToPlayers
    )
        internal
        returns (Lottery lottery)
    {
        uint8 selectionSize = uint8(vm.envUint("LOTTERY_SELECTION_SIZE"));
        uint256[] memory fixedRewards = new uint256[](selectionSize);

        lottery = new Lottery(
            LotterySetupParams(
                rewardToken,
                LotteryDrawSchedule(
                    vm.envUint("LOTTERY_FIRST_DRAW_AT"),
                    vm.envUint("LOTTERY_DRAW_PERIOD"),
                    vm.envUint("LOTTERY_DRAW_COOL_DOWN_PERIOD")
                ),
                vm.envUint("LOTTERY_TICKET_PRICE"),
                selectionSize,
                uint8(vm.envUint("LOTTERY_SELECTION_MAX")),
                uint256(vm.envUint("LOTTERY_EXPECTED_PAYOUT")),
                fixedRewards
            ),
            inflationPerDraw,
            percentageRewardsToPlayers,
            vm.envUint("SOURCE_MAX_FAILED_ATTEMPTS"),
            vm.envUint("SOURCE_MAX_REQUEST_DELAY")
        );
    }
}
