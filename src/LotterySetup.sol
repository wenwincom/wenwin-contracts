// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "src/PercentageMath.sol";
import "src/LotteryToken.sol";
import "src/interfaces/ILotterySetup.sol";
import "src/Ticket.sol";

contract LotterySetup is ILotterySetup {
    using PercentageMath for uint256;

    uint256 public immutable override jackpotBound;
    uint256 public immutable override maxPot;

    IERC20 public immutable override rewardToken;

    uint256 public immutable override ticketPrice;

    uint256 public immutable override initialPot;

    uint256 internal immutable firstDrawSchedule;
    uint256 public immutable override drawPeriod;
    uint256 public immutable override drawCoolDownPeriod;

    uint8 public immutable override selectionSize;
    uint8 public immutable override selectionMax;
    uint256 public immutable override expectedPayout;

    uint256 private immutable nonJackpotFixedRewards;

    uint256 private constant BASE_JACKPOT_PERCENTAGE = 30_030; // 30.03%

    uint256 private constant DRAW_PERIOD_MASK = 0xFFFFFFFF;
    uint256 private constant MIN_DRAW_PERIOD = 60 * 5; // 5 minutes

    /// @dev Constructs a new lottery contract
    /// @param lotterySetupParams Setup parameter for the lottery
    // solhint-disable-next-line code-complexity
    constructor(LotterySetupParams memory lotterySetupParams) {
        if (address(lotterySetupParams.token) == address(0)) {
            revert RewardTokenZero();
        }
        if (lotterySetupParams.ticketPrice == uint256(0)) {
            revert TicketPriceZero();
        }
        if (lotterySetupParams.selectionSize == 0) {
            revert SelectionSizeZero();
        }
        if (lotterySetupParams.selectionMax >= 120) {
            revert SelectionSizeMaxTooBig();
        }
        if (
            lotterySetupParams.expectedPayout < lotterySetupParams.ticketPrice / 100
                || lotterySetupParams.expectedPayout >= lotterySetupParams.ticketPrice
        ) {
            revert InvalidExpectedPayout();
        }
        if (
            lotterySetupParams.selectionSize > 16 || lotterySetupParams.selectionSize >= lotterySetupParams.selectionMax
        ) {
            revert SelectionSizeTooBig();
        }
        (uint256[] memory periods, uint256 length,) = unpackDrawPeriod(lotterySetupParams.drawSchedule.drawPeriod);
        if (length == 0) {
            revert DrawPeriodInvalidSetup();
        }
        uint256 shortestPeriod = type(uint256).max;
        for (uint256 i = 0; i < length; i++) {
            if (periods[i] < MIN_DRAW_PERIOD) {
                revert DrawPeriodInvalidSetup();
            }
            if (periods[i] < shortestPeriod) {
                shortestPeriod = periods[i];
            }
        }
        if (
            lotterySetupParams.drawSchedule.drawCoolDownPeriod >= shortestPeriod
                || lotterySetupParams.drawSchedule.firstDrawScheduledAt < shortestPeriod
        ) {
            revert DrawPeriodInvalidSetup();
        }

        uint256 tokenUnit = 10 ** IERC20Metadata(address(lotterySetupParams.token)).decimals();
        if (lotterySetupParams.initialPot < 4 * tokenUnit) {
            revert InsufficientInitialPot(lotterySetupParams.initialPot);
        }

        jackpotBound = 2_000_000 * tokenUnit;
        maxPot = 6_660_000 * tokenUnit;
        rewardToken = lotterySetupParams.token;
        firstDrawSchedule = lotterySetupParams.drawSchedule.firstDrawScheduledAt;
        drawPeriod = lotterySetupParams.drawSchedule.drawPeriod;
        drawCoolDownPeriod = lotterySetupParams.drawSchedule.drawCoolDownPeriod;
        ticketPrice = lotterySetupParams.ticketPrice;
        selectionSize = lotterySetupParams.selectionSize;
        selectionMax = lotterySetupParams.selectionMax;
        expectedPayout = lotterySetupParams.expectedPayout;

        rewardToken.transferFrom(msg.sender, address(this), lotterySetupParams.initialPot);
        initialPot = lotterySetupParams.initialPot;

        nonJackpotFixedRewards = packFixedRewards(lotterySetupParams.fixedRewards);

        emit LotteryDeployed(
            lotterySetupParams.token,
            lotterySetupParams.drawSchedule,
            lotterySetupParams.ticketPrice,
            lotterySetupParams.selectionSize,
            lotterySetupParams.selectionMax,
            lotterySetupParams.expectedPayout,
            lotterySetupParams.fixedRewards,
            lotterySetupParams.initialPot
        );
    }

    modifier beforeTicketRegistrationDeadline(uint128 drawId) {
        // slither-disable-next-line timestamp
        if (block.timestamp > ticketRegistrationDeadline(drawId)) {
            revert TicketRegistrationClosed(drawId);
        }
        _;
    }

    function fixedReward(uint8 winTier) public view override returns (uint256 amount) {
        if (winTier == selectionSize) {
            return _baseJackpot(initialPot);
        } else if (winTier == 0 || winTier > selectionSize) {
            return 0;
        } else {
            uint256 mask = uint256(type(uint16).max) << (winTier * 16);
            uint256 extracted = (nonJackpotFixedRewards & mask) >> (winTier * 16);
            return extracted * (10 ** (IERC20Metadata(address(rewardToken)).decimals() - 1));
        }
    }

    function drawScheduledAt(uint128 drawId) public view override returns (uint256 time) {
        (uint256[] memory periods, uint256 length, uint256 sum) = unpackDrawPeriod(drawPeriod);
        time = firstDrawSchedule + (drawId / length) * sum;

        for (uint256 i = 0; i < (drawId % length); i++) {
            time += periods[i];
        }
    }

    function ticketRegistrationDeadline(uint128 drawId) public view override returns (uint256 time) {
        time = drawScheduledAt(drawId) - drawCoolDownPeriod;
    }

    function _baseJackpot(uint256 _initialPot) internal view returns (uint256) {
        return Math.min(_initialPot.getPercentage(BASE_JACKPOT_PERCENTAGE), jackpotBound);
    }

    /// @dev Unpacks draw periods from uint256.
    /// @param drawPeriodInput uint256 representation of uint32 array of period duration.
    /// @return periods Arry of periods duration.
    /// @return length Number of elements in `periods` array.
    /// @return sum Sum of all elements in `periods` array.
    function unpackDrawPeriod(uint256 drawPeriodInput)
        private
        pure
        returns (uint256[] memory periods, uint256 length, uint256 sum)
    {
        uint256 tempPeriod = drawPeriodInput;
        periods = new uint256[](8);
        while (tempPeriod != 0) {
            uint256 currentPeriod = (tempPeriod & DRAW_PERIOD_MASK);
            sum += currentPeriod;
            periods[length++] = currentPeriod;
            tempPeriod >>= 32;
        }
    }

    function packFixedRewards(uint256[] memory rewards) private view returns (uint256 packed) {
        if (rewards.length != (selectionSize) || rewards[0] != 0) {
            revert InvalidFixedRewardSetup();
        }
        uint256 divisor = 10 ** (IERC20Metadata(address(rewardToken)).decimals() - 1);
        for (uint8 winTier = 1; winTier < selectionSize; ++winTier) {
            uint16 reward = uint16(rewards[winTier] / divisor);
            if ((rewards[winTier] % divisor) != 0) {
                revert InvalidFixedRewardSetup();
            }
            packed |= uint256(reward) << (winTier * 16);
        }
    }
}
