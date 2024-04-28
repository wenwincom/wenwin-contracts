// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Lottery.sol";
import "./TestToken.sol";

abstract contract LotteryTestBase is Test {
    Lottery public lottery;

    TestToken public rewardToken;
    uint256 public firstDrawAt;
    uint256 public constant PERIOD = 60 * 60 * 24; // 1 day
    uint256 public constant COOL_DOWN_PERIOD = 60; // 1 min
    uint256 public constant TICKET_PRICE = 5 ether;
    uint256 public constant TICKET_FEE = (TICKET_PRICE * 20) / 100;
    uint256 public constant TICKET_FRONTEND_FEE = (TICKET_PRICE * 10) / 100;
    uint8 public constant SELECTION_SIZE = 4;
    uint8 public constant SELECTION_MAX = 10;
    uint256 public constant EXPECTED_PAYOUT = 38e16;
    address public constant FRONTEND_ADDRESS = address(444);

    address rewardsRecipient = address(0x1936582);

    address public randomNumberSource = address(1_234_567_890);

    uint256[] public fixedRewards;

    uint256 public constant MAX_RN_FAILED_ATTEMPTS = 5;
    uint256 public constant MAX_RN_REQUEST_DELAY = 30 minutes;

    function setUp() public virtual {
        rewardToken = new TestToken();

        firstDrawAt = block.timestamp + 3 * PERIOD;

        fixedRewards = new uint256[](SELECTION_SIZE);
        fixedRewards[1] = TICKET_PRICE;
        fixedRewards[2] = 2 * TICKET_PRICE;
        fixedRewards[3] = 3 * TICKET_PRICE;

        vm.startPrank(address(987_651_234));
        rewardToken.mint(1e24);
        address predictedAddress = computeCreateAddress(address(987_651_234), vm.getNonce(address(987_651_234)));
        rewardToken.approve(predictedAddress, 1e24);

        lottery = new Lottery(
            LotterySetupParams(
                rewardToken,
                LotteryDrawSchedule(firstDrawAt, PERIOD, COOL_DOWN_PERIOD),
                TICKET_PRICE,
                SELECTION_SIZE,
                SELECTION_MAX,
                EXPECTED_PAYOUT,
                fixedRewards,
                1e24
            ),
            rewardsRecipient,
            MAX_RN_FAILED_ATTEMPTS,
            MAX_RN_REQUEST_DELAY,
            ""
        );
        lottery.initSource(IRNSource(randomNumberSource));
        vm.stopPrank();

        vm.mockCall(randomNumberSource, abi.encodeWithSelector(IRNSource.requestRandomNumber.selector), abi.encode(0));
    }

    function buyTicket(uint128 draw, uint120 ticket, address referrer) internal returns (uint256 ticketId) {
        uint128[] memory drawIds = new uint128[](1);
        drawIds[0] = draw;
        uint120[] memory tickets = new uint120[](1);
        tickets[0] = ticket;

        uint256[] memory ticketIds = lottery.buyTickets(drawIds, tickets, FRONTEND_ADDRESS, referrer);
        return ticketIds.length > 0 ? ticketIds[0] : 0;
    }

    function buySameTickets(
        uint128 drawId,
        uint120 ticket,
        address referrer,
        uint256 count
    )
        internal
        returns (uint256[] memory)
    {
        rewardToken.mint(TICKET_PRICE * count);
        rewardToken.approve(address(lottery), TICKET_PRICE * count);
        uint128[] memory drawIds = new uint128[](count);
        uint120[] memory tickets = new uint120[](count);
        for (uint256 i = 0; i < count; ++i) {
            drawIds[i] = drawId;
            tickets[i] = ticket;
        }
        return lottery.buyTickets(drawIds, tickets, FRONTEND_ADDRESS, referrer);
    }

    function finalizeDraw(uint256 randomNumber) internal {
        vm.warp(lottery.drawScheduledAt(lottery.currentDraw()));
        lottery.executeDraw();
        vm.prank(randomNumberSource);
        lottery.onRandomNumberFulfilled(randomNumber);
    }
}
