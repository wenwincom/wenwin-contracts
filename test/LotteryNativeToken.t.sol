// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./LotteryTestBase.sol";
import "../src/Lottery.sol";
import "./TestToken.sol";
import "test/TestHelpers.sol";
import "./WrappedNativeToken.sol";
import "../src/LotteryNativeToken.sol";

contract LotteryNativeTokenTest is LotteryTestBase {
    address public constant USER = address(123);

    function setUp() public override {
        rewardToken = new WrappedNativeToken();

        super.setUp();
    }

    function testBuyTicketWithNativeToken() public {
        uint128 currentDraw = lottery.currentDraw();
        uint256 initialBalance = rewardToken.balanceOf(address(lottery));

        vm.deal(USER, 10 ether);

        vm.startPrank(USER);
        uint256 ticketId = buyTicketWithNativeToken(currentDraw, uint120(0x0F), address(0));

        assertEq(rewardToken.balanceOf(address(lottery)), initialBalance + TICKET_PRICE);
        assertEq(lottery.ownerOf(ticketId), USER);
        assertEq(lottery.balanceOf(USER), 1);

        uint128[] memory drawIds = new uint128[](1);
        drawIds[0] = currentDraw;
        uint120[] memory tickets = new uint120[](1);
        tickets[0] = uint120(0x0F);

        vm.expectRevert(abi.encodeWithSelector(InsufficientNativeToken.selector));
        ILotteryNativeToken(address(lottery)).buyTicketsWithNativeToken{ value: TICKET_PRICE - 1 }(
            drawIds, tickets, FRONTEND_ADDRESS, address(0)
        );

        vm.stopPrank();

        vm.warp(lottery.drawScheduledAt(lottery.currentDraw()) + 1);
        lottery.executeDraw();

        // no winning ticket
        uint256 randomNumber = 0x01000000;
        vm.prank(randomNumberSource);
        lottery.onRandomNumberFulfilled(randomNumber);

        vm.expectRevert(abi.encodeWithSelector(TicketRegistrationClosed.selector, currentDraw));
        buyTicketWithNativeToken(currentDraw, uint120(0x0F), address(0));
    }

    function testNonJackpotWinClaimableInNativeToken() public {
        uint128 drawId = lottery.currentDraw();
        uint120 winningTicketNumbers = 0x8E;

        vm.deal(USER, 15 * TICKET_PRICE);

        vm.startPrank(USER);
        IWrappedNativeToken(address(rewardToken)).deposit{ value: 11 * TICKET_PRICE }();
        rewardToken.approve(address(lottery), 11 * TICKET_PRICE);
        uint256 ticketId = buyTicket(drawId, winningTicketNumbers, address(0));

        for (uint256 i = 0; i < 10; i++) {
            // buy the same tickets to increase nonJackpot count
            buyTicket(drawId, uint120(0xF0), address(0));
        }
        vm.stopPrank();

        // this will give winning ticket of 0x0F so 0x8E will have 3/4
        finalizeDraw(0);

        uint120 winningTicket = lottery.winningTicket(drawId);
        uint256 winTier = TicketUtils.ticketWinTier(winningTicketNumbers, winningTicket, SELECTION_SIZE, SELECTION_MAX);
        assertEq(winTier, 3);

        uint256 nativeTokenBalanceBefore = address(USER).balance;

        uint256[] memory ticketIds = new uint256[](1);
        ticketIds[0] = ticketId;

        vm.prank(USER);
        ILotteryNativeToken(address(lottery)).claimWinningTicketsInNativeToken(ticketIds);

        uint256 nativeTokenBalanceAfter = address(USER).balance;
        uint256 nativeTokenLotteryBalance = address(lottery).balance;

        assertEq(nativeTokenBalanceAfter - nativeTokenBalanceBefore, fixedRewards[winTier]);
        assertEq(nativeTokenLotteryBalance, 0);
    }

    function mintRewardToken() internal override {
        vm.deal(address(987_651_234), 1e24);

        vm.startPrank(address(987_651_234));
        IWrappedNativeToken(address(rewardToken)).deposit{ value: 1e24 }();
        address predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        IWrappedNativeToken(address(rewardToken)).approve(predictedAddress, 1e24);
    }

    function createLottery(
        IERC20Metadata rewardToken_,
        uint256 firstDrawAt_,
        uint256[] memory fixedRewards_,
        address rewardsRecipient_
    )
        internal
        override
        returns (Lottery)
    {
        return new LotteryNativeToken(
            LotterySetupParams(
                rewardToken_,
                LotteryDrawSchedule(firstDrawAt_, PERIOD, COOL_DOWN_PERIOD),
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                fixedRewards_,
                1e24
            ),
            rewardsRecipient_,
            MAX_RN_REQUEST_DELAY,
            ""
        );
    }

    function buyTicketWithNativeToken(
        uint128 draw,
        uint120 ticket,
        address referrer
    )
        internal
        returns (uint256 ticketId)
    {
        uint128[] memory drawIds = new uint128[](1);
        drawIds[0] = draw;
        uint120[] memory tickets = new uint120[](1);
        tickets[0] = ticket;

        uint256[] memory ticketIds = ILotteryNativeToken(address(lottery)).buyTicketsWithNativeToken{
            value: TICKET_PRICE
        }(drawIds, tickets, FRONTEND_ADDRESS, referrer);
        return ticketIds.length > 0 ? ticketIds[0] : 0;
    }
}
