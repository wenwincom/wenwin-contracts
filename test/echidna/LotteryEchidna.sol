// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import { Hevm } from "./Hevm.sol";
import { RNSourceEchidna } from "./RNSourceEchidna.sol";
import { StakingEchidna } from "./StakingEchidna.sol";
import { Lottery } from "src/Lottery.sol";
import "src/LotteryToken.sol";
import "../TestToken.sol";

contract LotteryEchidna {
    address internal constant HEVM_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

    uint256 internal constant MAX_REQUEST_DELAY = 60; // 1 min
    uint8 internal constant ECHIDNA_MAX_NUMBER_OF_DRAWS = 48; // 4 years

    TestToken internal rewardToken;
    uint256 internal firstDrawAt;
    uint256 internal constant PERIOD = 30 days;
    uint256 internal constant COOL_DOWN_PERIOD = 1 hours;
    uint256 internal constant TICKET_PRICE = 5 ether;
    uint8 internal constant SELECTION_SIZE = 7;
    uint8 internal constant SELECTION_MAX = 8;
    uint256 internal constant EXPECTED_PAYOUT = 38e16;

    Lottery internal lottery;

    ILotteryToken internal lotteryToken;
    uint256 public playerRewardFirstDraw;
    uint256 public playerRewardDecrease;
    uint256[] internal rewardsToReferrersPerDraw;
    uint256[] internal fixedRewards;

    uint256 internal rewardTokenLotteryBalance;
    bool internal drawExecutionInProgressEchidna;
    uint128 internal drawIdEchidna;
    mapping(address => uint256[]) internal boughtTickets;
    uint256 internal numberOfClaimedTickets;

    RNSourceEchidna internal rnSource;
    StakingEchidna internal stakingEchidna;

    event Log(string, uint256);

    constructor() {
        firstDrawAt = block.timestamp + 3 * PERIOD;
        rewardToken = new TestToken();

        rewardsToReferrersPerDraw = new uint256[](105);
        rewardsToReferrersPerDraw[0] = 700_000e18;
        rewardsToReferrersPerDraw[52] = 500_000e18;
        rewardsToReferrersPerDraw[104] = 300_000e18;
        for (uint256 i = 1; i < 104; i++) {
            if (i % 52 != 0) {
                rewardsToReferrersPerDraw[i] = rewardsToReferrersPerDraw[i - 1];
            }
        }

        fixedRewards = new uint256[](SELECTION_SIZE);
        for (uint8 counter = 1; counter < SELECTION_SIZE; counter++) {
            fixedRewards[counter] = counter * TICKET_PRICE;
        }

        //vm.startPrank(address(987_651_234));
        rewardToken.mint(1e24);
        //address predictedAddress = computeCreateAddress(address(987_651_234), 1);
        //rewardToken.approve(predictedAddress, 1e24);

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
            address(0x121212),
            MAX_REQUEST_DELAY,
            ""
        );

        rnSource = new RNSourceEchidna(address(lottery));
        lottery.initSource(rnSource);

        //vm.stopPrank();
    }

    function buyTicket(uint120 ticketCombination, address frontend, address referrer) public virtual {
        uint128[] memory drawIds = new uint128[](1);
        drawIds[0] = lottery.currentDraw();
        uint120[] memory tickets = new uint120[](1);
        tickets[0] = ticketCombination;
        buyTickets_(drawIds, tickets, frontend, referrer);
    }

    function buyTicket(uint128 drawId, uint120 ticketCombination, address frontend, address referrer) public virtual {
        uint128[] memory drawIds = new uint128[](1);
        drawIds[0] = drawId % ECHIDNA_MAX_NUMBER_OF_DRAWS;
        uint120[] memory tickets = new uint120[](1);
        tickets[0] = ticketCombination;
        buyTickets_(drawIds, tickets, frontend, referrer);
    }

    function buyTickets(
        uint128[] memory drawIds,
        uint120[] memory ticketCombinations,
        address frontend,
        address referrer
    )
        public
        virtual
    {
        for (uint256 counter = 0; counter < drawIds.length; ++counter) {
            drawIds[counter] = drawIds[counter] % ECHIDNA_MAX_NUMBER_OF_DRAWS;
        }
        buyTickets_(drawIds, ticketCombinations, frontend, referrer);
    }

    function executeDraw() external {
        executeDraw_();
    }

    function fulfillRandomNumber(uint256 randomNumber) external {
        fulfillRandomNumber_(randomNumber);
    }

    function claimWinningTickets(
        uint256[] memory ticketIdsRandom,
        bool isRandom,
        uint8 numberOfDraws,
        uint256 randomNumber
    )
        external
    {
        // Pre-condition
        uint256[] memory ticketIds;
        uint256[] memory ticketIdsFilter;
        uint256 filterCounter;
        if (isRandom) {
            uint256 totalSupply = lottery.nextTicketId();
            ticketIdsFilter = new uint256[](ticketIdsRandom.length);
            for (uint256 counter = 0; counter < ticketIdsRandom.length; ++counter) {
                uint256 ticketId = ticketIdsRandom[counter] % totalSupply;
                bool found;
                for (uint256 innerCounter = 0; innerCounter < counter; ++innerCounter) {
                    if (ticketId == ticketIdsFilter[innerCounter]) {
                        found = true;
                    }
                }
                if (!found) {
                    ticketIdsFilter[filterCounter] = ticketId;
                    ++filterCounter;
                }
            }
        } else {
            ticketIdsFilter = new uint256[](boughtTickets[msg.sender].length);
            for (uint256 counter = 0; counter < boughtTickets[msg.sender].length; ++counter) {
                ticketIdsFilter[filterCounter] = boughtTickets[msg.sender][counter];
                ++filterCounter;
            }
        }
        ticketIds = new uint256[](filterCounter);
        for (uint256 counter = 0; counter < filterCounter; counter++) {
            ticketIds[counter] = ticketIdsFilter[counter];
        }

        require(ticketIds.length > 0, "No tickets to claim");
        if (numberOfDraws < 1) {
            emit Log("claimWinningTickets", numberOfDraws);
        } else if (numberOfDraws < 12) {
            emit Log("claimWinningTickets", numberOfDraws);
        } else if (numberOfDraws < 24) {
            emit Log("claimWinningTickets", numberOfDraws);
        } else {
            emit Log("claimWinningTickets", numberOfDraws);
        }
        executeAndFulfillNumber_(numberOfDraws, randomNumber);

        uint256 claimedAmountInternal;
        for (uint256 counter = 0; counter < ticketIds.length; ++counter) {
            require(lottery.ownerOf(ticketIds[counter]) != address(0), "Ticket not owned");
            (uint256 claimableAmount,) = lottery.claimable(ticketIds[counter]);
            claimedAmountInternal += claimableAmount;
        }
        uint256 senderRewardTokenBalanceBefore = rewardToken.balanceOf(address(msg.sender));
        uint256 lotteryTokenBalanceBefore = rewardToken.balanceOf(address(lottery));

        // Action
        Hevm(HEVM_ADDRESS).prank(msg.sender);
        try lottery.claimWinningTickets(ticketIds) returns (uint256 claimedAmount) {
            // Post-condition
            uint256 senderRewardTokenBalanceAfter = rewardToken.balanceOf(address(msg.sender));
            assert(senderRewardTokenBalanceBefore + claimedAmount == senderRewardTokenBalanceAfter);
            uint256 lotteryTokenBalanceAfter = rewardToken.balanceOf(address(lottery));
            assert(lotteryTokenBalanceBefore - claimedAmount == lotteryTokenBalanceAfter);
            assert(claimedAmountInternal == claimedAmount);
            for (uint256 counter = 0; counter < ticketIds.length; ++counter) {
                assert(lottery.ownerOf(ticketIds[counter]) == msg.sender);
                (uint256 claimableAmount,) = lottery.claimable(ticketIds[counter]);
                assert(claimableAmount == 0);
            }
            rewardTokenLotteryBalance -= claimedAmount;
            numberOfClaimedTickets += ticketIds.length;
            assert(checkNumberOfClaimedTickets());
        } catch (bytes memory reason) {
            // Reverts
            bytes32 reasonInBytes32 = keccak256(reason);

            for (uint256 counter = 0; counter < ticketIds.length; ++counter) {
                // UnauthorizedClaim revert
                if (lottery.ownerOf(ticketIds[counter]) != msg.sender) {
                    bytes32 unauthorizedClaimBytes =
                        keccak256(abi.encodeWithSelector(UnauthorizedClaim.selector, ticketIds[counter], msg.sender));
                    assert(reasonInBytes32 == unauthorizedClaimBytes);
                    return;
                }

                // NothingToClaim revert
                (uint256 claimableAmount,) = lottery.claimable(ticketIds[counter]);
                if (claimableAmount == 0) {
                    bytes32 nothingToClaimBytes =
                        keccak256(abi.encodeWithSelector(NothingToClaim.selector, ticketIds[counter]));
                    assert(reasonInBytes32 == nothingToClaimBytes);
                    return;
                }
            }

            assert(false);
        }
    }

    function claimRewards(uint8 rewardTypeRandom) external {
        // Pre-condition
        bool isFrontend = rewardTypeRandom % 2 == 0;
        uint256 rewardBalanceBefore = getRewardBalance(isFrontend);

        Hevm(HEVM_ADDRESS).prank(isFrontend ? msg.sender : lottery.feeRecipient());
        uint256 claimedAmount = isFrontend ? lottery.claimFrontendFees() : lottery.claimFees();

        // Post-condition
        uint256 rewardBalanceAfter = getRewardBalance(isFrontend);
        assert(rewardBalanceBefore + claimedAmount == rewardBalanceAfter);
        rewardTokenLotteryBalance -= claimedAmount;
    }

    function stakingEchidnaStake(uint256 amount) external {
        Hevm(HEVM_ADDRESS).prank(msg.sender);
        stakingEchidna.stake(amount);
    }

    function stakingEchidnaWithdraw(uint256 amount) external {
        Hevm(HEVM_ADDRESS).prank(msg.sender);
        stakingEchidna.withdraw(amount);
    }

    function stakingEchidnaGetReward() external {
        Hevm(HEVM_ADDRESS).prank(msg.sender);
        stakingEchidna.getReward();
    }

    function stakingEchidnaExit() external {
        Hevm(HEVM_ADDRESS).prank(msg.sender);
        stakingEchidna.exit();
    }

    function buyTickets_(
        uint128[] memory drawIds,
        uint120[] memory ticketCombinations,
        address frontend,
        address referrer
    )
        private
    {
        // Pre-condition
        uint256 drawIdsLength = drawIds.length;
        // This if-else structure helps Echidna increase its corpus by artificially forcing it to buy 0, 1-9, 10-19 etc.
        // tickets at once in different flows.
        if (drawIdsLength < 1) {
            emit Log("buyTickets_", drawIdsLength);
        } else if (drawIdsLength < 10) {
            emit Log("buyTickets_", drawIdsLength);
        } else if (drawIdsLength < 50) {
            emit Log("buyTickets_", drawIdsLength);
        } else if (drawIdsLength < 100) {
            emit Log("buyTickets_", drawIdsLength);
        } else {
            emit Log("buyTickets_", drawIdsLength);
        }

        uint256 senderRewardTokenBalanceBefore = rewardToken.balanceOf(address(msg.sender));
        Hevm(HEVM_ADDRESS).prank(msg.sender);
        rewardToken.mint(TICKET_PRICE * ticketCombinations.length);
        Hevm(HEVM_ADDRESS).prank(msg.sender);
        rewardToken.approve(address(lottery), TICKET_PRICE * ticketCombinations.length);
        uint256 rewardTokenBalanceBefore = rewardToken.balanceOf(address(lottery));

        // Action
        Hevm(HEVM_ADDRESS).prank(msg.sender);
        try lottery.buyTickets(drawIds, ticketCombinations, frontend, referrer) returns (uint256[] memory ticketIds) {
            // Post-condition
            assert(ticketIds.length == drawIds.length);
            uint256 ticketSumPrice = ticketIds.length * TICKET_PRICE;
            assert(rewardTokenBalanceBefore + ticketSumPrice == rewardToken.balanceOf(address(lottery)));
            assert(rewardToken.balanceOf(msg.sender) == senderRewardTokenBalanceBefore);
            for (uint256 counter = 0; counter < ticketIds.length; ++counter) {
                assert(isValidTicket(ticketCombinations[counter]));
                boughtTickets[msg.sender].push(ticketIds[counter]);
            }
            rewardTokenLotteryBalance += ticketSumPrice;
        } catch (bytes memory reason) {
            // Reverts
            bytes32 reasonInBytes32 = keccak256(reason);

            // DrawsAndTicketsLenMismatch revert
            if (
                reasonInBytes32
                    == keccak256(
                        abi.encodeWithSelector(
                            DrawsAndTicketsLenMismatch.selector, drawIds.length, ticketCombinations.length
                        )
                    )
            ) {
                assert(drawIds.length != ticketCombinations.length);
                return;
            }

            for (uint256 counter = 0; counter < drawIds.length; ++counter) {
                // TicketRegistrationClosed revert
                if (block.timestamp > lottery.ticketRegistrationDeadline(drawIds[counter])) {
                    assert(
                        reasonInBytes32
                            == keccak256(abi.encodeWithSelector(TicketRegistrationClosed.selector, drawIds[counter]))
                    );
                    return;
                }

                // InvalidTicket revert
                if (!isValidTicket(ticketCombinations[counter])) {
                    assert(reasonInBytes32 == keccak256(abi.encodeWithSelector(InvalidTicket.selector)));
                    return;
                }
            }

            assert(false);
        }
    }

    function validateRewardWonType(uint128 drawId) internal view returns (bool) {
        uint8 selectionSize = lottery.selectionSize();
        if (lottery.winAmount(drawId, selectionSize) > 0) {
            for (uint8 counter = 0; counter < selectionSize; ++counter) {
                if (lottery.winAmount(drawId, counter) > 0) {
                    return false;
                }
            }
        } else {
            for (uint8 counter = 1; counter < selectionSize; ++counter) {
                if (lottery.winAmount(drawId, counter) == 0) {
                    return false;
                }
            }
        }
        return true;
    }

    function checkNumberOfClaimedTickets() internal view returns (bool) {
        return (numberOfClaimedTickets <= lottery.nextTicketId());
    }

    function executeDraw_() private {
        // Pre-condition
        bool executingDrawBefore = lottery.drawExecutionInProgress();

        // Action
        try lottery.executeDraw() {
            // Post-condition
            assert(!executingDrawBefore);
            assert(lottery.drawExecutionInProgress() == true);
            drawExecutionInProgressEchidna = true;
        } catch (bytes memory reason) {
            // Reverts
            bytes32 reasonInBytes32 = keccak256(reason);

            // DrawAlreadyInProgress revert
            if (reasonInBytes32 == keccak256(abi.encodeWithSelector(DrawAlreadyInProgress.selector))) {
                assert(executingDrawBefore == true);
                return;
            }

            // ExecutingDrawTooEarly revert
            if (reasonInBytes32 == keccak256(abi.encodeWithSelector(ExecutingDrawTooEarly.selector))) {
                uint128 currentDrawId = lottery.currentDraw();
                assert(block.timestamp < lottery.drawScheduledAt(currentDrawId));
                return;
            }

            assert(false);
        }
    }

    function fulfillRandomNumber_(uint256 randomNumber) private {
        // Pre-condition
        require(rnSource.isRequested(), "RNSource alredy requested");
        bool drawExecutionInProgressBefore = lottery.drawExecutionInProgress();
        uint128 drawIdBefore = lottery.currentDraw();

        // Action
        try rnSource.fulfillRandomNumber(randomNumber) {
            // Post-condition
            assert(drawExecutionInProgressBefore);
            assert(lottery.drawExecutionInProgress() == false);
            assert(drawIdBefore + 1 == lottery.currentDraw());
            assert(validateRewardWonType(drawIdBefore) == true);
            drawExecutionInProgressEchidna = false;
            drawIdEchidna = lottery.currentDraw();
        } catch (bytes memory reason) {
            // Reverts
            bytes32 reasonInBytes32 = keccak256(reason);

            // Unauthorized revert
            if (reasonInBytes32 == keccak256(abi.encodeWithSelector(RandomNumberFulfillmentUnauthorized.selector))) {
                assert(msg.sender == address(rnSource));
                return;
            }

            // DrawNotInProgress revert
            if (reasonInBytes32 == keccak256(abi.encodeWithSelector(DrawNotInProgress.selector))) {
                assert(drawExecutionInProgressBefore == false);
                return;
            }

            assert(false);
        }
    }

    function executeAndFulfillNumber_(uint8 numberOfDraws, uint256 randomNumber) private {
        uint8 numberOfDrawsScaled = numberOfDraws % ECHIDNA_MAX_NUMBER_OF_DRAWS;
        for (uint8 counter = 0; counter < numberOfDrawsScaled; ++counter) {
            Hevm(HEVM_ADDRESS).warp(block.timestamp + PERIOD);
            executeDraw_();
            fulfillRandomNumber_(randomNumber % block.timestamp);
        }
    }

    function isValidTicket(uint256 numberForCount) private pure returns (bool) {
        uint8 _count = 0;
        for (uint8 i = 0; i < SELECTION_MAX; ++i) {
            if (numberForCount & 1 == 1) {
                _count++;
            }
            numberForCount >>= 1;
        }
        return ((_count == SELECTION_SIZE) && (numberForCount == uint256(0)));
    }

    function getRewardBalance(bool isFrontend) private view returns (uint256) {
        return rewardToken.balanceOf(isFrontend ? msg.sender : lottery.feeRecipient());
    }
}
