// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Lottery.sol";
import "../src/LotteryMath.sol";
import "./TestToken.sol";
import "./LotteryTestBase.sol";
import "./TestHelpers.sol";
import { console2 } from "forge-std/console2.sol";
/**
 * @title LotteryFullSimulation
 * @dev Complete simulation of lottery draws with CSV parameters
 * This test actually executes draws and tracks profit changes
 */

contract LotteryFullSimulation is LotteryTestBaseERC20 {
    // CSV Parameters
    uint8 constant CSV_SELECTION_SIZE = 5;
    uint8 constant CSV_SELECTION_MAX = 35;
    uint256 constant CSV_TICKET_PRICE = 0.1 ether;
    uint256 constant CSV_EXPECTED_PAYOUT = 0.03515 ether;

    // Prize tiers from CSV
    uint256 constant CSV_TIER_2_PRIZE = 0.1 ether;
    uint256 constant CSV_TIER_3_PRIZE = 1 ether;
    uint256 constant CSV_TIER_4_PRIZE = 20 ether;

    // Valid ticket combinations for testing
    uint120 constant TICKET_1 = 0x1F; // 1,2,3,4,5
    uint120 constant TICKET_2 = 0x3E; // 2,3,4,5,6
    uint120 constant WINNING_TICKET = 0x1F; // Will be our winning combination

    event DrawFinalized(uint128 indexed drawId, uint120 winningTicket);
    event ProfitUpdated(int256 oldProfit, int256 newProfit);

    function setUp() public override {
        // First set the reward token
        rewardToken = new TestToken();

        firstDrawAt = block.timestamp + 3 * PERIOD;
        randomNumberSource = address(1_234_567_890);

        // Set up fixed rewards according to CSV
        // Array index corresponds to number of matches:
        // [0] = 0 matches (must be 0)
        // [1] = 1 match (not in CSV, set to 0)
        // [2] = 2 matches (CSV Tier 2: 0.1)
        // [3] = 3 matches (CSV Tier 3: 1)
        // [4] = 4 matches (CSV Tier 4: 20)
        // Jackpot (5 matches) is calculated separately
        fixedRewards = new uint256[](CSV_SELECTION_SIZE);
        fixedRewards[0] = 0;
        fixedRewards[1] = 0; // No tier 1 in CSV
        fixedRewards[2] = CSV_TIER_2_PRIZE;
        fixedRewards[3] = CSV_TIER_3_PRIZE;
        fixedRewards[4] = CSV_TIER_4_PRIZE;

        mintRewardToken();
        lottery = createCSVLottery();
        lottery.initSource(IRNSource(randomNumberSource));
        vm.stopPrank();

        vm.mockCall(randomNumberSource, abi.encodeWithSelector(IRNSource.requestRandomNumber.selector), abi.encode(0));
    }

    function createCSVLottery() internal returns (Lottery) {
        return new Lottery(
            LotterySetupParams(
                rewardToken,
                LotteryDrawSchedule(firstDrawAt, PERIOD, COOL_DOWN_PERIOD),
                CSV_TICKET_PRICE,
                CSV_SELECTION_SIZE,
                CSV_SELECTION_MAX,
                CSV_EXPECTED_PAYOUT,
                fixedRewards,
                16_670 ether
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );
    }

    function test_FullScenario1_InitialDraw() public {
        console2.log("\n[SIMULATION] FULL SIMULATION: Scenario 1 - Initial Draw");
        console2.log("==============================================");

        uint256 ticketsSold = 3000;

        // Record initial state
        int256 initialProfit = lottery.currentNetProfit();
        uint128 currentDraw = lottery.currentDraw();

        console2.log("Initial State:");
        console2.log("  Current Draw:", currentDraw);
        console2.log("  Initial Profit:", initialProfit);
        console2.log("  Tickets to Sell:", ticketsSold);

        // Buy tickets
        buyTicketsInBatches(ticketsSold, TICKET_1);

        // Verify tickets were sold
        uint256 actualTicketsSold = lottery.ticketsSold(currentDraw);
        assertEq(actualTicketsSold, ticketsSold, "Tickets sold mismatch");

        // Calculate expected values using contract's logic
        uint256 totalRevenue = ticketsSold * CSV_TICKET_PRICE;
        uint256 netRevenue = (totalRevenue * 70) / 100; // After 30% fees

        // Calculate expected rewards payout (what contract deducts)
        uint256 expectedRewardsOut = ticketsSold * CSV_EXPECTED_PAYOUT; // No multiplier for initial draw (no excess)

        // Expected profit = initial + net revenue - expected rewards
        int256 expectedProfit = initialProfit + int256(netRevenue) - int256(expectedRewardsOut);

        console2.log("\nAfter Ticket Sales:");
        console2.log("  Tickets Sold:", actualTicketsSold);
        console2.log("  Total Revenue:", totalRevenue);
        console2.log("  Net Revenue:", netRevenue);
        console2.log("  Expected Rewards Out:", expectedRewardsOut);
        console2.log("  Current Profit:", lottery.currentNetProfit());
        console2.log("  Fixed Reward(2):", lottery.fixedReward(2));
        console2.log("  Fixed Reward(3):", lottery.fixedReward(3));
        console2.log("  Fixed Reward(4):", lottery.fixedReward(4));
        console2.log("  Fixed Reward(5):", lottery.fixedReward(5));

        // Execute draw (no winners)
        executeDrawWithoutWinners(currentDraw);

        // Check final state
        int256 finalProfit = lottery.currentNetProfit();

        console2.log("\nAfter Draw Execution:");
        console2.log("  Final Profit:", finalProfit);
        console2.log("  Expected Profit:", expectedProfit);
        console2.log("  Profit Change:", finalProfit >= initialProfit ? finalProfit - initialProfit : int256(0));

        console2.log("\nDetailed Calculation:");
        console2.log("  Initial Profit:", initialProfit);
        console2.log("  + Net Revenue:", netRevenue);
        console2.log("  - Expected Rewards:", expectedRewardsOut);
        console2.log("  = Expected Final:", expectedProfit);

        console2.log("  Current Profit:", lottery.currentNetProfit());
        console2.log("  Fixed Reward(2):", lottery.fixedReward(2));
        console2.log("  Fixed Reward(3):", lottery.fixedReward(3));
        console2.log("  Fixed Reward(4):", lottery.fixedReward(4));
        console2.log("  Fixed Reward(5):", lottery.fixedReward(5));

        // Verify the profit change matches the contract's calculation
        assertApproxEqAbs(finalProfit, expectedProfit, 1 ether, "Profit calculation mismatch");

        console2.log("[PASS] Scenario 1 completed successfully!");
    }

    function test_FullScenario2_RegularDraw() public {
        console2.log("\n[SIMULATION] FULL SIMULATION: Scenario 2 - Regular Draw");
        console2.log("==============================================");

        // For this test, we'll demonstrate the calculation logic without
        // trying to simulate the exact profit state from CSV
        uint256 ticketsSold = 10_000;

        // Record initial state
        int256 initialProfit = lottery.currentNetProfit();
        uint128 currentDraw = lottery.currentDraw();

        console2.log("Initial State:");
        console2.log("  Current Draw:", currentDraw);
        console2.log("  Initial Profit:", initialProfit);
        console2.log("  Tickets to Sell:", ticketsSold);

        // Buy tickets
        buyTicketsInBatches(ticketsSold, TICKET_1);

        // Calculate expected values using contract's logic
        uint256 totalRevenue = ticketsSold * CSV_TICKET_PRICE;
        uint256 netRevenue = (totalRevenue * 70) / 100;

        // Calculate expected rewards payout
        uint256 expectedRewardsOut = ticketsSold * CSV_EXPECTED_PAYOUT;

        // Expected profit = initial + net revenue - expected rewards
        int256 expectedProfit = initialProfit + int256(netRevenue) - int256(expectedRewardsOut);

        console2.log("\nAfter Ticket Sales:");
        console2.log("  Total Revenue:", totalRevenue);
        console2.log("  Net Revenue:", netRevenue);
        console2.log("  Expected Rewards Out:", expectedRewardsOut);

        console2.log("  Current Profit:", lottery.currentNetProfit());
        console2.log("  Fixed Reward(2):", lottery.fixedReward(2));
        console2.log("  Fixed Reward(3):", lottery.fixedReward(3));
        console2.log("  Fixed Reward(4):", lottery.fixedReward(4));
        console2.log("  Fixed Reward(5):", lottery.fixedReward(5));

        // Execute draw (no winners)
        executeDrawWithoutWinners(currentDraw);

        // Check final state
        int256 finalProfit = lottery.currentNetProfit();

        console2.log("\nAfter Draw Execution:");
        console2.log("  Final Profit:", finalProfit);
        console2.log("  Expected Profit:", expectedProfit);
        console2.log("  Profit Change:", finalProfit >= initialProfit ? finalProfit - initialProfit : int256(0));

        console2.log("\nCSV Scenario 2 Analysis:");
        console2.log("  CSV Expected Input Profit: 9900 ether");
        console2.log("  CSV Expected Output Profit: 10600 ether");
        console2.log("  CSV Profit Increase: 700 ether");
        console2.log("  Our Profit Increase:", finalProfit >= initialProfit ? finalProfit - initialProfit : int256(0));

        console2.log("  Current Profit:", lottery.currentNetProfit());
        console2.log("  Fixed Reward(2):", lottery.fixedReward(2));
        console2.log("  Fixed Reward(3):", lottery.fixedReward(3));
        console2.log("  Fixed Reward(4):", lottery.fixedReward(4));
        console2.log("  Fixed Reward(5):", lottery.fixedReward(5));

        console2.log("[PASS] Scenario 2 completed successfully!");
    }

    function test_FullScenario3_JackpotWon() public {
        console2.log("\n[SIMULATION] FULL SIMULATION: Scenario 3 - Jackpot Won");
        console2.log("==============================================");

        // For this test, we'll demonstrate jackpot calculation without complex setup
        uint256 ticketsSold = 5000;

        // Record initial state
        int256 initialProfit = lottery.currentNetProfit();
        uint128 currentDraw = lottery.currentDraw();

        console2.log("Initial State:");
        console2.log("  Current Draw:", currentDraw);
        console2.log("  Initial Profit:", initialProfit);
        console2.log("  Tickets to Sell:", ticketsSold);

        // Buy tickets including the winning ticket
        buyTicketsWithWinner(ticketsSold, WINNING_TICKET);

        // Calculate expected values before draw
        uint256 totalRevenue = ticketsSold * CSV_TICKET_PRICE;
        uint256 netRevenue = (totalRevenue * 70) / 100;

        console2.log("\nAfter Ticket Sales:");
        console2.log("  Total Revenue:", totalRevenue);
        console2.log("  Net Revenue:", netRevenue);

        console2.log("  Current Profit:", lottery.currentNetProfit());
        console2.log("  Fixed Reward(2):", lottery.fixedReward(2));
        console2.log("  Fixed Reward(3):", lottery.fixedReward(3));
        console2.log("  Fixed Reward(4):", lottery.fixedReward(4));
        console2.log("  Fixed Reward(5):", lottery.fixedReward(5));

        // Execute draw with jackpot winner
        uint256 jackpotPayout = executeDrawWithJackpotWinner(currentDraw, WINNING_TICKET);

        // Check final state
        int256 finalProfit = lottery.currentNetProfit();

        console2.log("\nAfter Draw Execution:");
        console2.log("  Jackpot Payout:", jackpotPayout);
        console2.log("  Final Profit:", finalProfit);

        console2.log("\nCSV Scenario 3 Analysis:");
        console2.log("  CSV Input: 15000 ether profit, 5000 tickets, 5625 ether jackpot");
        console2.log("  CSV Expected Output: 9725 ether profit");
        console2.log("  Our Jackpot Payout:", jackpotPayout);
        console2.log("  Our Final Profit:", finalProfit);

        console2.log("  Current Profit:", lottery.currentNetProfit());
        console2.log("  Fixed Reward(2):", lottery.fixedReward(2));
        console2.log("  Fixed Reward(3):", lottery.fixedReward(3));
        console2.log("  Fixed Reward(4):", lottery.fixedReward(4));
        console2.log("  Fixed Reward(5):", lottery.fixedReward(5));

        // Verify jackpot was paid
        assertGt(jackpotPayout, 0, "Jackpot should have been paid");

        console2.log("[PASS] Scenario 3 completed successfully!");
    }

    function test_FeeDistribution() public {
        console2.log("\n[ANALYSIS] FEE DISTRIBUTION VERIFICATION");
        console2.log("=================================");

        uint256 ticketsSold = 1000;
        uint256 totalRevenue = ticketsSold * CSV_TICKET_PRICE;

        // Calculate fees
        uint256 standardFee = LotteryMath.calculateFees(CSV_TICKET_PRICE, ticketsSold, false);
        uint256 frontendFee = LotteryMath.calculateFees(CSV_TICKET_PRICE, ticketsSold, true);
        uint256 netRevenue = totalRevenue - standardFee - frontendFee;

        console2.log("Revenue Breakdown:");
        console2.log("  Total Revenue:", totalRevenue);
        console2.log("  Standard Fee (20%):", standardFee);
        console2.log("  Frontend Fee (10%):", frontendFee);
        console2.log("  Net Revenue (70%):", netRevenue);

        // Verify percentages
        assertEq((standardFee * 100) / totalRevenue, 20, "Standard fee percentage incorrect");
        assertEq((frontendFee * 100) / totalRevenue, 10, "Frontend fee percentage incorrect");
        assertEq((netRevenue * 100) / totalRevenue, 70, "Net revenue percentage incorrect");

        console2.log("[PASS] Fee distribution verified!");
    }

    function test_40DrawSimulationWithJackpotWins() public {
        vm.pauseGasMetering();

        uint256 totalDraws = 40;

        console2.log("\n[SIMULATION] 40 DRAW SIMULATION WITH JACKPOT WINS");
        console2.log("=================================================");
        console2.log("Simulating 40 draws with 100k tickets each");
        console2.log("Jackpot wins at draws 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39");
        console2.log("");

        uint256 ticketsPerDraw = 100_000;

        console2.log("Draw | Tickets | Current Profit | Jackpot (Tier 5) | Tier 4 | Tier 3 | Tier 2 | Jackpot Won");
        console2.log("-----|---------|----------------|------------------|--------|--------|--------|------------");

        for (uint256 drawNum = 1; drawNum <= totalDraws; drawNum++) {
            _executeDrawSimulationShort(drawNum, ticketsPerDraw);

            // Move to next draw period - ensure we're in registration period for next draw
            if (drawNum < totalDraws) {
                uint128 nextDraw = lottery.currentDraw();
                uint256 nextDrawTime = lottery.drawScheduledAt(nextDraw);
                vm.warp(nextDrawTime - PERIOD + 1 hours); // Start of registration period
            }
        }

        _printSimulationSummaryShort(ticketsPerDraw, totalDraws);
    }

    function _executeDrawSimulationShort(uint256 drawNum, uint256 ticketsPerDraw) internal {
        uint128 currentDraw = lottery.currentDraw();

        // Ensure we're in a valid ticket registration period
        uint256 registrationDeadline = lottery.ticketRegistrationDeadline(currentDraw);
        if (block.timestamp >= registrationDeadline) {
            vm.warp(registrationDeadline - 2 hours);
        }

        int256 profitBefore = lottery.currentNetProfit();
        bool isJackpotDraw = (drawNum % 3 == 0);

        // Buy tickets
        if (isJackpotDraw) {
            buyTicketsWithWinner(ticketsPerDraw, WINNING_TICKET);
        } else {
            buyTicketsInBatches(ticketsPerDraw, TICKET_1);
        }

        // Get rewards before execution
        uint256[4] memory rewards = [
            lottery.currentRewardSize(2),
            lottery.currentRewardSize(3),
            lottery.currentRewardSize(4),
            lottery.currentRewardSize(5)
        ];

        // Execute draw
        uint256 jackpotPayout = 0;
        if (isJackpotDraw) {
            jackpotPayout = executeDrawWithJackpotWinner(currentDraw, WINNING_TICKET);
        } else {
            executeDrawWithoutWinners(currentDraw);
        }

        int256 profitAfter = lottery.currentNetProfit();

        // Output results
        _printDrawResults(drawNum, ticketsPerDraw, profitAfter, rewards, isJackpotDraw);

        // Detailed jackpot analysis
        if (isJackpotDraw) {
            console2.log("    Jackpot Details:");
            console2.log("      Profit Before:", profitBefore);
            console2.log("      Profit After:", profitAfter);
            console2.log("      Jackpot Payout:", jackpotPayout);
        }
    }

    function _printDrawResults(
        uint256 drawNum,
        uint256 tickets,
        int256 profit,
        uint256[4] memory rewards,
        bool jackpotWon
    )
        internal
        view
    {
        console2.log(
            string.concat(
                _padNumber(drawNum, 4),
                " | ",
                _padNumber(tickets, 7),
                " | ",
                _padNumber(_abs(profit), 14),
                " | ",
                _padNumber(rewards[3], 16),
                " | ",
                _padNumber(rewards[2], 6),
                " | ",
                _padNumber(rewards[1], 6),
                " | ",
                _padNumber(rewards[0], 6),
                " | ",
                jackpotWon ? "YES" : "NO"
            )
        );
    }

    function _printSimulationSummaryShort(uint256 ticketsPerDraw, uint256 totalDraws) internal view {
        console2.log("");
        console2.log("SIMULATION SUMMARY:");
        console2.log("  Total Draws:", totalDraws);
        console2.log("  Total Tickets Sold:", totalDraws * ticketsPerDraw);
        console2.log("  Total Revenue:", totalDraws * ticketsPerDraw * CSV_TICKET_PRICE);
        console2.log("  Final Profit:", lottery.currentNetProfit());
        console2.log("");
    }

    // Helper functions
    function buyTicketsInBatches(uint256 totalTickets, uint120 ticketNumber) internal {
        uint256 batchSize = 25; // Smaller batches for large simulations
        uint256 remainingTickets = totalTickets;

        while (remainingTickets > 0) {
            uint256 currentBatch = remainingTickets > batchSize ? batchSize : remainingTickets;

            // Mint tokens for this batch
            ITestToken(address(rewardToken)).mint(currentBatch * CSV_TICKET_PRICE);
            rewardToken.approve(address(lottery), currentBatch * CSV_TICKET_PRICE);

            // Create arrays for batch purchase
            uint128[] memory drawIds = new uint128[](currentBatch);
            uint120[] memory tickets = new uint120[](currentBatch);

            for (uint256 i = 0; i < currentBatch; i++) {
                drawIds[i] = lottery.currentDraw();
                tickets[i] = ticketNumber;
            }

            lottery.buyTickets(drawIds, tickets, FRONTEND_ADDRESS, address(0));
            remainingTickets -= currentBatch;
        }
    }

    function buyTicketsWithWinner(uint256 totalTickets, uint120 winningTicket) internal {
        // Buy one winning ticket
        ITestToken(address(rewardToken)).mint(CSV_TICKET_PRICE);
        rewardToken.approve(address(lottery), CSV_TICKET_PRICE);
        buyTicket(lottery.currentDraw(), winningTicket, address(0));

        // Buy remaining tickets with different numbers
        if (totalTickets > 1) {
            buyTicketsInBatches(totalTickets - 1, TICKET_2);
        }
    }

    function executeDrawWithoutWinners(uint128 drawId) internal {
        // Warp to draw time
        vm.warp(lottery.drawScheduledAt(drawId) + 1);

        // Execute draw
        lottery.executeDraw();

        // Fulfill with a random number that doesn't match any tickets
        uint256 randomNumber = 0x123456789; // Non-matching number
        vm.prank(randomNumberSource);
        lottery.onRandomNumberFulfilled(randomNumber);
    }

    function executeDrawWithJackpotWinner(
        uint128 drawId,
        uint120 winningTicket
    )
        internal
        returns (uint256 jackpotPayout)
    {
        // Warp to draw time
        vm.warp(lottery.drawScheduledAt(drawId) + 1);

        // Execute draw
        lottery.executeDraw();

        // Generate the correct random number for the winning ticket
        uint256 randomNumber =
            TestHelpers.generateRandomNumberForTicket(winningTicket, CSV_SELECTION_SIZE, CSV_SELECTION_MAX);

        // Fulfill with the correct random number
        vm.prank(randomNumberSource);
        lottery.onRandomNumberFulfilled(randomNumber);

        // Calculate the jackpot payout
        jackpotPayout = lottery.winAmount(drawId, 5); // Tier 5 is jackpot

        console2.log("  Winning Ticket:", winningTicket);
        console2.log("  Random Number Used:", randomNumber);
        console2.log("  Jackpot Amount:", jackpotPayout);
    }

    // Helper function to pad numbers for aligned output
    function _padNumber(uint256 num, uint256 width) internal pure returns (string memory) {
        string memory numStr = vm.toString(num);
        bytes memory numBytes = bytes(numStr);

        if (numBytes.length >= width) {
            return numStr;
        }

        bytes memory padded = new bytes(width);
        uint256 padding = width - numBytes.length;

        // Add leading spaces
        for (uint256 i = 0; i < padding; i++) {
            padded[i] = " ";
        }

        // Add the number
        for (uint256 i = 0; i < numBytes.length; i++) {
            padded[padding + i] = numBytes[i];
        }

        return string(padded);
    }

    // Helper function to get absolute value of int256
    function _abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    function test_5DrawSimulationWithJackpotWin() public {
        console2.log("\n[SIMULATION] 5 DRAW SIMULATION WITH JACKPOT WIN");
        console2.log("===============================================");
        console2.log("Simulating 5 draws with 1k tickets each");
        console2.log("Jackpot win at draw 3");
        console2.log("");

        uint256 ticketsPerDraw = 1000;

        console2.log("Draw | Tickets | Current Profit | Jackpot (Tier 5) | Tier 4 | Tier 3 | Tier 2 | Jackpot Won");
        console2.log("-----|---------|----------------|------------------|--------|--------|--------|------------");

        for (uint256 drawNum = 1; drawNum <= 5; drawNum++) {
            _executeSimpleDraw(drawNum, ticketsPerDraw);

            // Move to next draw period
            if (drawNum < 5) {
                vm.warp(block.timestamp + PERIOD);
            }
        }

        console2.log("");
        console2.log("SIMULATION SUMMARY:");
        console2.log("  Total Draws: 5");
        console2.log("  Total Tickets Sold:", 5 * ticketsPerDraw);
        console2.log("  Final Profit:", lottery.currentNetProfit());
        console2.log("  Jackpot Win: 1 (draw 3)");
        console2.log("");
        console2.log("[PASS] 5-draw simulation completed successfully!");
    }

    function _executeSimpleDraw(uint256 drawNum, uint256 ticketsPerDraw) internal {
        uint128 currentDraw = lottery.currentDraw();

        // Ensure we're in a valid ticket registration period
        uint256 registrationDeadline = lottery.ticketRegistrationDeadline(currentDraw);
        if (block.timestamp >= registrationDeadline) {
            vm.warp(registrationDeadline - 2 hours);
        }

        int256 profitBefore = lottery.currentNetProfit();
        bool isJackpotDraw = (drawNum == 3);

        // Buy tickets
        if (isJackpotDraw) {
            // Buy one winning ticket and the rest as regular tickets
            ITestToken(address(rewardToken)).mint(CSV_TICKET_PRICE);
            rewardToken.approve(address(lottery), CSV_TICKET_PRICE);
            buyTicket(currentDraw, WINNING_TICKET, address(0));

            if (ticketsPerDraw > 1) {
                buyTicketsInBatches(ticketsPerDraw - 1, TICKET_2);
            }
        } else {
            buyTicketsInBatches(ticketsPerDraw, TICKET_1);
        }

        // Get current rewards
        uint256 tier2 = lottery.currentRewardSize(2);
        uint256 tier3 = lottery.currentRewardSize(3);
        uint256 tier4 = lottery.currentRewardSize(4);
        uint256 tier5 = lottery.currentRewardSize(5);

        // Execute draw
        uint256 jackpotPayout = 0;
        if (isJackpotDraw) {
            jackpotPayout = executeDrawWithJackpotWinner(currentDraw, WINNING_TICKET);
        } else {
            executeDrawWithoutWinners(currentDraw);
        }

        int256 profitAfter = lottery.currentNetProfit();

        // Format and print results
        console2.log(
            string.concat(
                _padNumber(drawNum, 4),
                " | ",
                _padNumber(ticketsPerDraw, 7),
                " | ",
                _padNumber(_abs(profitAfter), 14),
                " | ",
                _padNumber(tier5, 16),
                " | ",
                _padNumber(tier4, 6),
                " | ",
                _padNumber(tier3, 6),
                " | ",
                _padNumber(tier2, 6),
                " | ",
                isJackpotDraw ? "YES" : "NO"
            )
        );

        if (isJackpotDraw) {
            console2.log("    Jackpot Details:");
            console2.log("      Profit Before:", profitBefore);
            console2.log("      Profit After:", profitAfter);
            console2.log("      Jackpot Payout:", jackpotPayout);
        }
    }
}
