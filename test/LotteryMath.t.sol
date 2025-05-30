// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/LotteryMath.sol";
import "src/PercentageMath.sol";

contract LotteryMathTest is Test {
    using PercentageMath for uint256;

    // solhint-disable-next-line no-empty-blocks
    function setUp() public { }

    function testCalculateJackpotReward(uint256 netProfit, uint256 fixedJackpotSize, uint256 ticketsSold) public {
        int256 profit = int256(bound(netProfit, 0, 1e48)) - 1e24;
        fixedJackpotSize = bound(fixedJackpotSize, 1e23, 25e25);
        uint256 expectedPayout = 38e16;
        uint256 excess = LotteryMath.calculateExcessPot(profit, fixedJackpotSize);
        uint256 reward =
            LotteryMath.calculateReward(profit, fixedJackpotSize, fixedJackpotSize, ticketsSold, true, expectedPayout);
        assertGe(reward, fixedJackpotSize);
        assertEq(reward, fixedJackpotSize + excess / 4);
    }

    function testCalculateNonJackpotReward(
        uint256 netProfit,
        uint256 fixedReward,
        uint256 ticketsSold,
        uint256 fixedJackpotSize
    )
        public
    {
        int256 profit = int256(bound(netProfit, 0, 1e48)) - 1e48 / 2;
        ticketsSold = bound(ticketsSold, 0, 1e10);
        fixedJackpotSize = bound(fixedJackpotSize, 1e23, 25e25);
        fixedReward = bound(fixedReward, 0, 1e22);
        uint256 expectedPayout = 38e16;

        uint256 excess = LotteryMath.calculateExcessPot(profit, fixedJackpotSize);
        uint256 reward =
            LotteryMath.calculateReward(profit, fixedReward, fixedJackpotSize, ticketsSold, false, expectedPayout);
        if (fixedReward == 0) {
            assertEq(reward, 0);
        } else {
            assertGe(reward, fixedReward);
            assertEq(
                reward,
                fixedReward * LotteryMath.calculateMultiplier(excess, ticketsSold, expectedPayout)
                    / PercentageMath.PERCENTAGE_BASE
            );
        }
    }

    function testCalculateMultiplier(uint256 excessPot, uint256 ticketsSold) public {
        excessPot = bound(excessPot, 0, 1e25);
        ticketsSold = bound(ticketsSold, 0, 1e10);
        uint256 expectedPayout = 38e16;
        uint256 multi = LotteryMath.calculateMultiplier(excessPot, ticketsSold, expectedPayout);
        if (excessPot * ticketsSold == 0) {
            assertEq(multi, PercentageMath.PERCENTAGE_BASE);
        } else {
            assertGe(multi, PercentageMath.PERCENTAGE_BASE);
            uint256 totalExpectedPayout = ticketsSold * expectedPayout;
            uint256 multiCalc =
                PercentageMath.PERCENTAGE_BASE + (excessPot / 4) * PercentageMath.PERCENTAGE_BASE / totalExpectedPayout;
            assertEq(multiCalc, multi);
        }
    }

    function testCalculateExcessPot(uint256 netProfit, uint256 fixedJackpotSize) public {
        int256 profit = int256(bound(netProfit, 0, 1e68)) - 1e68 / 2;
        fixedJackpotSize = bound(fixedJackpotSize, 1e23, 25e25);
        uint256 excess = LotteryMath.calculateExcessPot(profit, fixedJackpotSize);
        if (profit <= 0) {
            assertEq(excess, 0);
        } else {
            uint256 excessCalc = uint256(profit) * 5 / 100;
            if (excessCalc <= fixedJackpotSize) {
                assertEq(excess, 0);
            } else {
                assertEq(excess, excessCalc - fixedJackpotSize);
            }
        }
    }

    function testCalculateStakingFees(uint256 ticketPrice, uint256 ticketsSold) public {
        ticketPrice = bound(ticketPrice, 1e18, 5e18);
        ticketsSold = bound(ticketsSold, 1, 1e12);
        assertEq((ticketsSold * ticketPrice) / 5, LotteryMath.calculateFees(ticketPrice, ticketsSold, false));
    }

    function testCalculateFrontendFees(uint256 ticketPrice, uint256 ticketsSold) public {
        ticketPrice = bound(ticketPrice, 1e18, 5e18);
        ticketsSold = bound(ticketsSold, 1, 1e12);
        assertEq((ticketsSold * ticketPrice) / 10, LotteryMath.calculateFees(ticketPrice, ticketsSold, true));
    }

    function testCalculateNewProfit(int256 oldProfit, uint256 ticketsSold, uint256 expectedPayout) public {
        uint256 ticketPrice = 1.5e18;
        oldProfit = bound(oldProfit, -1e27, 1e27);
        ticketsSold = bound(ticketsSold, 1, 1e7);
        expectedPayout = bound(expectedPayout, 1, ticketPrice.getPercentage(LotteryMath.TICKET_PRICE_TO_POT) - 1);

        assertGe(
            LotteryMath.calculateNewProfit(oldProfit, ticketsSold, ticketPrice, false, 1e24, expectedPayout),
            (oldProfit < 0 ? oldProfit : int256(0))
        );
    }
}
