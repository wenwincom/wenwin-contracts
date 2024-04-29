// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./LotteryTestBase.sol";
import "../src/Lottery.sol";
import "./TestToken.sol";
import "test/TestHelpers.sol";

contract LotteryTest is LotteryTestBase {
    address public constant USER = address(123);

    function testFinalizeInitialPot(uint256 initialSize) public {
        vm.warp(0);
        uint256 tokenUnit = 10 ** rewardToken.decimals();
        initialSize = bound(initialSize, 0, 6_660_000 * tokenUnit);
        vm.startPrank(address(987_651_234));
        rewardToken.mint(initialSize);
        address predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, initialSize);
        if (initialSize < 4 * tokenUnit) {
            vm.expectRevert(abi.encodeWithSelector(InsufficientInitialPot.selector, initialSize));
        }
        new Lottery(
            LotterySetupParams(
                rewardToken,
                LotteryDrawSchedule(2 * PERIOD, PERIOD, COOL_DOWN_PERIOD),
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                fixedRewards,
                initialSize
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );
        vm.stopPrank();
    }

    function testBuyInvalidTicket() public {
        uint128 currentDraw = lottery.currentDraw();

        vm.startPrank(USER);
        rewardToken.mint(TICKET_PRICE);
        rewardToken.approve(address(lottery), TICKET_PRICE);

        vm.expectRevert(InvalidTicket.selector);
        buyTicket(currentDraw, uint120(0x0E), address(0));

        // Cannot buy 10000000111
        vm.expectRevert(InvalidTicket.selector);
        buyTicket(currentDraw, uint120(0x407), address(0));

        // Can buy 1000000111
        buyTicket(currentDraw, uint120(0x207), address(0));
    }

    function testBuyTicket() public {
        uint128 currentDraw = lottery.currentDraw();
        uint256 initialBalance = rewardToken.balanceOf(address(lottery));

        vm.startPrank(USER);
        rewardToken.mint(5 ether);
        rewardToken.approve(address(lottery), 10 ether);
        buyTicket(currentDraw, uint120(0x0F), address(0));

        assertEq(rewardToken.balanceOf(address(lottery)), initialBalance + TICKET_PRICE);

        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        buyTicket(currentDraw, uint120(0x0F), address(0));

        vm.stopPrank();

        vm.warp(lottery.drawScheduledAt(lottery.currentDraw()) + 1);
        lottery.executeDraw();

        // no winning ticket
        uint256 randomNumber = 0x01000000;
        vm.prank(randomNumberSource);
        lottery.onRandomNumberFulfilled(randomNumber);

        rewardToken.mint(5 ether);
        rewardToken.approve(address(lottery), 5 ether);
        vm.expectRevert(abi.encodeWithSelector(TicketRegistrationClosed.selector, currentDraw));
        buyTicket(currentDraw, uint120(0x0F), address(0));
    }

    function testBuyMultipleTickets() public {
        vm.startPrank(USER);
        rewardToken.mint(TICKET_PRICE * 2);
        rewardToken.approve(address(lottery), TICKET_PRICE * 2);
        uint128[] memory drawIds = new uint128[](2);
        uint120[] memory tickets = new uint120[](3);
        vm.expectRevert(abi.encodeWithSelector(DrawsAndTicketsLenMismatch.selector, 2, 3));
        lottery.buyTickets(drawIds, tickets, FRONTEND_ADDRESS, address(0));

        drawIds[0] = lottery.currentDraw();
        drawIds[1] = lottery.currentDraw() + 1;
        tickets = new uint120[](2);
        tickets[0] = 0x0F;
        tickets[1] = 0x0F;
        lottery.buyTickets(drawIds, tickets, FRONTEND_ADDRESS, address(0));
        // TODO
        // assertEq(lottery.potSize(lottery.currentDraw()), TICKET_PRICE - TICKET_FEE);
        // assertEq(lottery.potSize(lottery.currentDraw() + 1), TICKET_PRICE - TICKET_FEE);
    }

    function testClaimFees() public {
        vm.startPrank(USER);
        rewardToken.mint(TICKET_PRICE);
        rewardToken.approve(address(lottery), TICKET_PRICE);
        buyTicket(lottery.currentDraw(), uint120(0x0F), address(0));
        vm.stopPrank();

        assertEq(lottery.unclaimedFees(), TICKET_FEE);
        assertEq(lottery.unclaimedFrontendFees(FRONTEND_ADDRESS), TICKET_FRONTEND_FEE);

        address feeRecipient = lottery.feeRecipient();
        uint256 preBalance = rewardToken.balanceOf(feeRecipient);
        vm.prank(feeRecipient);
        lottery.claimFees();
        assertEq(lottery.unclaimedFees(), 0);
        assertEq(rewardToken.balanceOf(feeRecipient), preBalance + TICKET_FEE);

        preBalance = rewardToken.balanceOf(FRONTEND_ADDRESS);
        vm.prank(FRONTEND_ADDRESS);
        lottery.claimFrontendFees();
        assertEq(lottery.unclaimedFrontendFees(FRONTEND_ADDRESS), 0);
        assertEq(rewardToken.balanceOf(FRONTEND_ADDRESS), preBalance + TICKET_FRONTEND_FEE);
    }

    function testChangeFeeRecipient() public {
        vm.startPrank(USER);
        rewardToken.mint(TICKET_PRICE);
        rewardToken.approve(address(lottery), TICKET_PRICE);
        buyTicket(lottery.currentDraw(), uint120(0x0F), address(0));
        vm.stopPrank();

        assertEq(lottery.unclaimedFees(), TICKET_FEE);

        address feeRecipient = lottery.feeRecipient();
        uint256 preBalance = rewardToken.balanceOf(feeRecipient);

        vm.prank(feeRecipient);
        lottery.changeFeeRecipient(address(1234));
        assertEq(lottery.feeRecipient(), address(1234));
        assertEq(lottery.unclaimedFees(), 0);
        assertEq(rewardToken.balanceOf(feeRecipient), preBalance + TICKET_FEE);

        vm.expectRevert(Unauthorized.selector);
        lottery.changeFeeRecipient(address(0));

        vm.expectRevert(ZeroAddressProvided.selector);
        vm.prank(address(1234));
        lottery.changeFeeRecipient(address(0));
    }

    function testExecuteDraw() public {
        vm.startPrank(USER);
        rewardToken.mint(TICKET_PRICE);
        rewardToken.approve(address(lottery), TICKET_PRICE);
        uint256 nonWinningTicketId = buyTicket(lottery.currentDraw(), uint120(0xF0), address(0));
        vm.stopPrank();

        vm.expectRevert(ExecutingDrawTooEarly.selector);
        lottery.executeDraw();

        vm.warp(lottery.drawScheduledAt(lottery.currentDraw()) + 1);
        lottery.executeDraw();

        vm.expectRevert(DrawAlreadyInProgress.selector);
        lottery.executeDraw();

        // no winning ticket
        uint256 randomNumber = 0x00000000;
        vm.prank(randomNumberSource);
        lottery.onRandomNumberFulfilled(randomNumber);

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(NothingToClaim.selector, nonWinningTicketId));
        claimTicket(nonWinningTicketId);

        uint128 drawId = lottery.currentDraw();
        vm.startPrank(USER);
        rewardToken.mint(TICKET_PRICE);
        rewardToken.approve(address(lottery), TICKET_PRICE);
        uint256 ticketId = buyTicket(lottery.currentDraw(), uint120(0x0F), address(0));
        vm.stopPrank();

        vm.warp(block.timestamp + 60 * 60 * 24 + 1);
        lottery.executeDraw();

        // winning ticket
        randomNumber = 0x00000000;
        vm.prank(randomNumberSource);
        lottery.onRandomNumberFulfilled(randomNumber);

        vm.prank(address(0x01234567));
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedClaim.selector, ticketId, address(0x01234567)));
        claimTicket(ticketId);

        vm.prank(USER);
        claimTicket(ticketId);

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedClaim.selector, ticketId, USER));
        claimTicket(ticketId);

        assertEq(rewardToken.balanceOf(USER), lottery.winAmount(drawId, SELECTION_SIZE));
    }

    function testNonJackpotWinClaimable() public {
        uint128 drawId = lottery.currentDraw();
        uint256 ticketId = initTickets(drawId, 0x8E);

        // this will give winning ticket of 0x0F so 0x8E will have 3/4
        finalizeDraw(0);

        uint8 winTier = 3;
        checkTicketWinTier(drawId, 0x8E, winTier);
        claimWinnings(drawId, ticketId, winTier, fixedRewards[winTier]);
    }

    function testZeroClaimableAfterDeadline() public {
        uint128 drawId = lottery.currentDraw();
        uint256 ticketId = initTickets(drawId, 0xE8);
        uint256 claimable;

        finalizeDraw(0x01020304);
        for (uint256 i = drawId + 1; i <= drawId + LotteryMath.DRAWS_PER_YEAR; ++i) {
            (claimable,) = lottery.claimable(ticketId);
            assertGt(claimable, 0);
            finalizeDraw(i * 0x04003001);
        }

        (claimable,) = lottery.claimable(ticketId);
        assertEq(claimable, 0);
    }

    function testMultiClaim() public {
        uint128 drawId = lottery.currentDraw();
        uint256[] memory ticketIds = new uint256[](2);
        ticketIds[0] = initTickets(drawId, 0xE8);
        ticketIds[1] = initTickets(drawId, 0xE8);

        finalizeDraw(0x01020304);

        uint8 winTier = TicketUtils.ticketWinTier(0xE8, lottery.winningTicket(drawId), SELECTION_SIZE, SELECTION_MAX);
        uint256 preBalance = rewardToken.balanceOf(USER);
        vm.prank(USER);
        lottery.claimWinningTickets(ticketIds);
        assertEq(rewardToken.balanceOf(USER), preBalance + fixedRewards[winTier] * 2);
    }

    function testFixedReward() public {
        assertEq(lottery.fixedReward(0), 0);
        assertEq(lottery.fixedReward(SELECTION_SIZE + 1), 0);
        assertEq(lottery.fixedReward(SELECTION_SIZE - 1), fixedRewards[SELECTION_SIZE - 1]);
    }

    function testJackpotReturnToPot() public {
        uint256 claimable;
        uint256 claimable1;
        uint128 drawId = lottery.currentDraw();
        vm.startPrank(USER);
        rewardToken.mint(TICKET_PRICE * 2);
        rewardToken.approve(address(lottery), TICKET_PRICE * 2);
        uint256 ticketId = buyTicket(lottery.currentDraw(), uint120(0x0F), address(0));
        uint256 ticketId1 = buyTicket(lottery.currentDraw(), uint120(0x0F), address(0));
        vm.stopPrank();

        finalizeDraw(0x00000000);

        for (uint256 i = drawId + 1; i <= drawId + LotteryMath.DRAWS_PER_YEAR; ++i) {
            (claimable,) = lottery.claimable(ticketId);
            (claimable1,) = lottery.claimable(ticketId1);
            assertGt(claimable, 0);
            assertGt(claimable1, 0);
            finalizeDraw(i * 0x04003001);
        }
        (claimable,) = lottery.claimable(ticketId);
        (claimable1,) = lottery.claimable(ticketId1);
        assertEq(claimable, 0);
        assertEq(claimable1, 0);
    }

    function testRescueTokens() public {
        TestToken token = new TestToken();

        vm.startPrank(USER);
        token.mint(10);
        token.transfer(address(lottery), 10);
        vm.stopPrank();

        vm.startPrank(lottery.owner());
        vm.expectRevert(abi.encodeWithSelector(AmountToRescueTooBig.selector, token, 11, 10));
        lottery.rescueTokens(token, USER, 11);

        lottery.rescueTokens(token, USER, 10);
        assertEq(token.balanceOf(USER), 10);

        vm.expectRevert(abi.encodeWithSelector(AmountToRescueTooBig.selector, rewardToken, 1, 0));
        lottery.rescueTokens(rewardToken, USER, 1);

        vm.stopPrank();

        // buy some tickets
        vm.startPrank(USER);
        rewardToken.mint(TICKET_PRICE * 2);
        rewardToken.approve(address(lottery), TICKET_PRICE * 2);
        buyTicket(lottery.currentDraw(), uint120(0x0F), address(0));
        buyTicket(lottery.currentDraw(), uint120(0x0F), address(0));
        vm.stopPrank();

        uint128 drawId = lottery.currentDraw();

        for (uint256 i = drawId + 1; i <= drawId + LotteryMath.DRAWS_PER_YEAR; ++i) {
            finalizeDraw(i * 0x04003001);
        }

        uint256 balance = rewardToken.balanceOf(address(lottery));
        vm.startPrank(lottery.owner());
        vm.expectRevert(abi.encodeWithSelector(AmountToRescueTooBig.selector, rewardToken, balance + 1, balance));
        lottery.rescueTokens(rewardToken, USER, balance + 1);

        lottery.rescueTokens(rewardToken, USER, balance);
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(address(lottery)), 0);
    }

    function testMultiplePeriods() public {
        vm.startPrank(address(987_651_234));
        uint256 drawPeriodPacked = (3 days << 32) + 2 days;
        LotteryDrawSchedule memory drawSchedule =
            LotteryDrawSchedule(block.timestamp + 4 days, drawPeriodPacked, 30 minutes);
        rewardToken.mint(5e18);
        address predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        Lottery multiDraws = new Lottery(
            LotterySetupParams(
                rewardToken,
                drawSchedule,
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                fixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        assertEq(multiDraws.drawScheduledAt(0), block.timestamp + 4 days);
        assertEq(multiDraws.drawScheduledAt(1), multiDraws.drawScheduledAt(0) + 2 days);
        assertEq(multiDraws.drawScheduledAt(2), multiDraws.drawScheduledAt(1) + 3 days);

        drawPeriodPacked = (3 days << 64) + 2 days;
        LotteryDrawSchedule memory drawScheduleInvalid =
            LotteryDrawSchedule(block.timestamp + 3 days, drawPeriodPacked, 30 minutes);
        vm.expectRevert(DrawPeriodInvalidSetup.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken,
                drawScheduleInvalid,
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                fixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );
    }

    function testWrongSetups() public {
        vm.startPrank(address(987_651_234));

        LotteryDrawSchedule memory drawSchedule =
            LotteryDrawSchedule(block.timestamp + 3 * PERIOD, PERIOD, COOL_DOWN_PERIOD);

        vm.expectRevert(RewardTokenZero.selector);
        new Lottery(
            LotterySetupParams(
                IERC20(address(0)),
                drawSchedule,
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                fixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        address predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        vm.expectRevert(DrawPeriodInvalidSetup.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken,
                LotteryDrawSchedule(firstDrawAt, 0, COOL_DOWN_PERIOD),
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                fixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        vm.expectRevert(DrawPeriodInvalidSetup.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken,
                LotteryDrawSchedule(firstDrawAt, COOL_DOWN_PERIOD - 1, COOL_DOWN_PERIOD),
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                fixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        vm.expectRevert(TicketPriceZero.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken, drawSchedule, 0, SELECTION_SIZE, SELECTION_MAX, EXPECTED_PAYOUT, fixedRewards, 5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        vm.expectRevert(SelectionSizeZero.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken, drawSchedule, TICKET_PRICE, 0, SELECTION_MAX, EXPECTED_PAYOUT, fixedRewards, 5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        vm.expectRevert(SelectionSizeMaxTooBig.selector);
        new Lottery(
            LotterySetupParams(rewardToken, drawSchedule, TICKET_PRICE, 5, 120, EXPECTED_PAYOUT, fixedRewards, 5e18),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        vm.expectRevert(SelectionSizeTooBig.selector);
        new Lottery(
            LotterySetupParams(rewardToken, drawSchedule, TICKET_PRICE, 17, 20, EXPECTED_PAYOUT, fixedRewards, 5e18),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        vm.expectRevert(SelectionSizeTooBig.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken,
                drawSchedule,
                TICKET_PRICE,
                SELECTION_MAX,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                fixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        vm.expectRevert(InvalidExpectedPayout.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken,
                drawSchedule,
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                TICKET_PRICE / 250,
                fixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        vm.expectRevert(InvalidExpectedPayout.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken, drawSchedule, TICKET_PRICE, SELECTION_SIZE, SELECTION_MAX, TICKET_PRICE, fixedRewards, 5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        vm.expectRevert(InvalidFixedRewardSetup.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken,
                drawSchedule,
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                new uint256[](1),
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        uint256[] memory invalidFixedRewards = new uint256[](SELECTION_SIZE);
        invalidFixedRewards[SELECTION_SIZE - 1] = 1e15;
        vm.expectRevert(InvalidFixedRewardSetup.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken,
                drawSchedule,
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                invalidFixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        invalidFixedRewards[SELECTION_SIZE - 1] = 0;
        invalidFixedRewards[0] = 1e18;
        vm.expectRevert(InvalidFixedRewardSetup.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken,
                drawSchedule,
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                invalidFixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        invalidFixedRewards[0] = 0;
        invalidFixedRewards[1] = 1e18;
        invalidFixedRewards[2] = 100e18;
        invalidFixedRewards[3] = 6554e18;
        vm.expectRevert(FixedRewardIsOverMax.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken,
                drawSchedule,
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                invalidFixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        rewardToken.mint(5e18);
        predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        invalidFixedRewards[0] = 0;
        invalidFixedRewards[1] = 1e18;
        invalidFixedRewards[2] = 100e18;
        invalidFixedRewards[3] = 6554e18;
        vm.expectRevert(FixedRewardIsOverMax.selector);
        new Lottery(
            LotterySetupParams(
                rewardToken,
                drawSchedule,
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                invalidFixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        vm.stopPrank();
    }

    function testValidMaxFixedReward() public {
        LotteryDrawSchedule memory drawSchedule =
            LotteryDrawSchedule(block.timestamp + 3 * PERIOD, PERIOD, COOL_DOWN_PERIOD);

        uint256 tokenUnit = 10 ** rewardToken.decimals();
        vm.startPrank(address(987_651_234));
        rewardToken.mint(5e18);
        address predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 5e18);
        uint256[] memory validMaxFixedRewards = new uint256[](SELECTION_SIZE);
        validMaxFixedRewards[0] = 0;
        validMaxFixedRewards[1] = 1e18;
        validMaxFixedRewards[2] = 100e18;
        validMaxFixedRewards[3] = 6553e18;
        Lottery lotterySetup = new Lottery(
            LotterySetupParams(
                rewardToken,
                drawSchedule,
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                validMaxFixedRewards,
                5e18
            ),
            rewardsRecipient,
            MAX_RN_REQUEST_DELAY,
            ""
        );

        assertEq(lotterySetup.fixedReward(3) / tokenUnit, 6553);
    }

    // Token URI

    function testSetBaseURI() public {
        vm.startPrank(USER);
        rewardToken.mint(TICKET_PRICE);
        rewardToken.approve(address(lottery), TICKET_PRICE);
        buyTicket(0, uint120(0x0F), address(0));
        vm.stopPrank();

        assertEq(lottery.tokenURI(0), "");

        string memory baseURI = "https://api.test.com/lottery/";

        vm.prank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        lottery.setBaseURI(baseURI);

        vm.startPrank(lottery.owner());
        lottery.setBaseURI(baseURI);
        assertEq(lottery.tokenURI(0), string.concat(baseURI, "0"));
        vm.stopPrank();
    }

    function testClaimBeforeTransfer() public {
        uint128 drawId = lottery.currentDraw();
        uint256 ticketId = initTickets(drawId, 0x8E);
        // this will give winning ticket of 0x0F so 0x8E will have 3/4
        finalizeDraw(0);
        uint8 winTier = 3;
        checkTicketWinTier(drawId, 0x8E, winTier);

        address BUYER = address(456);
        vm.prank(USER);
        claimTicket(ticketId); // USER front-run trade transaction and claims rewards
        vm.prank(USER);
        vm.expectRevert("ERC721: invalid token ID");
        lottery.transferFrom(USER, BUYER, ticketId);
    }

    // Helper functions

    function initTickets(uint128 drawId, uint120 numbers) private returns (uint256 ticketId) {
        vm.startPrank(USER);
        rewardToken.mint(TICKET_PRICE);
        rewardToken.approve(address(lottery), TICKET_PRICE);
        ticketId = buyTicket(drawId, numbers, address(0));
        // buy the same tickets to increase nonJackpot count
        buySameTickets(drawId, uint120(0xF0), address(0), 10);
        vm.stopPrank();
    }

    function checkTicketWinTier(uint128 drawId, uint120 ticket, uint256 expectedWinTier) private {
        uint120 winningTicket = lottery.winningTicket(drawId);
        uint256 winTier = TicketUtils.ticketWinTier(ticket, winningTicket, SELECTION_SIZE, SELECTION_MAX);
        assertEq(winTier, expectedWinTier);
    }

    function preCheckNonJackpotWin(uint128 drawId, uint256 ticketId, uint8 winTier, uint256 claimable) private {
        assertEq(lottery.winAmount(drawId, winTier), claimable);
        (uint256 claimableReturned,) = lottery.claimable(ticketId);
        assertEq(claimableReturned, claimable);
    }

    function postCheckNonJackpotWin(uint256 ticketId, uint256 preBalance, uint256 claimable) private {
        assertEq(preBalance + claimable, rewardToken.balanceOf(USER));
        (uint256 claimableReturned,) = lottery.claimable(ticketId);
        assertEq(claimableReturned, 0);
    }

    function claimWinnings(uint128 drawId, uint256 ticketId, uint8 winTier, uint256 claimable) private {
        preCheckNonJackpotWin(drawId, ticketId, winTier, claimable);
        uint256 preBalance = rewardToken.balanceOf(USER);
        vm.prank(USER);
        claimTicket(ticketId);
        postCheckNonJackpotWin(ticketId, preBalance, claimable);
    }

    function claimTicket(uint256 ticketId) private {
        uint256[] memory ticketIds = new uint256[](1);
        ticketIds[0] = ticketId;
        lottery.claimWinningTickets(ticketIds);
    }
}
