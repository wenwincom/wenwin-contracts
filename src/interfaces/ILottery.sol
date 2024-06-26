// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "src/interfaces/ILotterySetup.sol";
import "src/interfaces/IRNSourceController.sol";
import "src/interfaces/ITicket.sol";
import "src/interfaces/IFeeCollector.sol";

/// @dev Invalid caller to the function.
error Unauthorized();

/// @dev Zero address was provided.
error ZeroAddressProvided();

/// @dev Invalid ticket is provided. This means the selection count is not `selectionSize`,
/// or one of the numbers is not in range [1, selectionMax].
error InvalidTicket();

/// @dev Cannot execute draw if it is already in progress.
error DrawAlreadyInProgress();

/// @dev Cannot finalize draw if it is not in executing phase.
error DrawNotInProgress();

/// @dev Executing draw before it's scheduled period.
error ExecutingDrawTooEarly();

/// @dev Provided arrays of drawIds and Tickets with different length.
/// @param drawIdsLen Length of drawIds array.
/// @param ticketsLen Length of tickets array.
error DrawsAndTicketsLenMismatch(uint256 drawIdsLen, uint256 ticketsLen);

/// @dev Claim executed by someone else other than ticket owner.
/// @param ticketId Unique ticket identifier being claimed.
/// @param claimer User trying to execute claim.
error UnauthorizedClaim(uint256 ticketId, address claimer);

/// @dev Trying to claim win for a non-winning ticket or a ticket that was already claimed.
/// @param ticketId Unique ticket identifier being claimed.
error NothingToClaim(uint256 ticketId);

/// @dev The draw with @param drawId is not finished
/// @param drawId Unique identifier for draw
error DrawNotFinished(uint128 drawId);

/// @dev Amount of tokens to rescue is to big.
/// @param token Token contract address.
/// @param amount Amount of tokens tried to rescue.
/// @param maxToWithdraw Maximum number of tokens available for withdrawal.
error AmountToRescueTooBig(IERC20 token, uint256 amount, uint256 maxToWithdraw);

/// @dev Interface that decentralized lottery implements
interface ILottery is ITicket, ILotterySetup, IRNSourceController, IFeeCollector {
    /// @dev New ticket has been purchased by `user` for `drawId`.
    /// @param currentDraw Currently active draw.
    /// @param ticketId Ticket unique identifier.
    /// @param drawId Draw for which the ticket was purchased.
    /// @param user Address of the user buying ticket.
    /// @param combination Ticket combination represented as packed uint120.
    /// @param frontend Frontend operator that sold the ticket.
    /// @param referrer Referrer address that referred ticket sale.
    event NewTicket(
        uint128 currentDraw,
        uint256 ticketId,
        uint128 drawId,
        address indexed user,
        uint120 combination,
        address indexed frontend,
        address indexed referrer
    );

    /// @dev Freontend fees are claimed from the lottery.
    /// @param frontend Address the frontend operator.
    /// @param amount Total amount of fees claimed.
    event ClaimedFrontendFees(address indexed frontend, uint256 indexed amount);

    /// @dev Winnings are claimed from the lottery for particular ticket
    /// @param user Address of the user claiming winnings.
    /// @param ticketId Ticket unique identifier.
    /// @param amount Total amount of winnings claimed.
    event ClaimedTicket(address indexed user, uint256 indexed ticketId, uint256 indexed amount);

    /// @dev Started executing draw for the drawId.
    /// @param drawId Draw that is being executed.
    event StartedExecutingDraw(uint128 indexed drawId);

    /// @dev Triggered after finishing the draw process.
    /// @param drawId Draw being finished.
    /// @param randomNumber Random number used for reconstructing ticket.
    /// @param winningTicket Winning ticket represented as packed uint120.
    event FinishedExecutingDraw(uint128 indexed drawId, uint256 indexed randomNumber, uint120 indexed winningTicket);

    /// @dev Tokens rescued from the contract.
    /// @param token Token contract address.
    /// @param to Address tokens were rescued to.
    /// @param amount Amount of tokens rescued.
    event TokenRescued(IERC20 token, address to, uint256 amount);

    /// @return Is executing draw in progress.
    function drawExecutionInProgress() external view returns (bool);

    /// @dev Checks amount to payout for winning ticket for particular draw.
    /// @param drawId Unique identifier of a draw we are querying.
    /// @param winTier Tier of the win (selectionSize for jackpot).
    /// @return amount Amount claimable by winning ticket holder.
    function winAmount(uint128 drawId, uint8 winTier) external view returns (uint256 amount);

    /// @dev Checks the current reward size for the particular win tier.
    /// @param winTier Tier of the win, `selectionSize` for jackpot.
    /// @return rewardSize Size of the reward for win tier.
    function currentRewardSize(uint8 winTier) external view returns (uint256 rewardSize);

    /// @param drawId Unique identifier of a draw we are querying.
    /// @return sold Number of tickets sold per draw.
    function ticketsSold(uint128 drawId) external view returns (uint256 sold);

    /// @return netProfit Current cumulative net profit calculated when the last draw was finished.
    function currentNetProfit() external view returns (int256 netProfit);

    /// @param frontend Address of the frontend operator.
    /// @return unclaimedAmount Amount of fees to be paid out.
    function unclaimedFrontendFees(address frontend) external view returns (uint256 unclaimedAmount);

    /// @return drawId Current game in progress.
    function currentDraw() external view returns (uint128 drawId);

    /// @dev Checks winning combination for particular draw.
    /// @param drawId Unique identifier of a draw we are querying.
    /// @return winningCombination Actual winning combination for a draw.
    function winningTicket(uint128 drawId) external view returns (uint120 winningCombination);

    /// @dev Changes fee recipient address. msg.sender needs to be old fee recipient.
    /// @param newFeeRecipient Address of the new fee recipient.
    function changeFeeRecipient(address newFeeRecipient) external;

    /// @dev Buy set of tickets for the upcoming lotteries.
    /// `msg.sender` pays `ticketPrice` for each ticket and provides combination of numbers for each ticket.
    /// Reverts in case of invalid number combination in any of the tickets.
    /// Reverts in case of insufficient `rewardToken`(`tickets.length * ticketPrice`) in `msg.sender`'s account.
    /// Requires approval to spend `msg.sender`'s `rewardToken` of at least `tickets.length * ticketPrice`
    /// @param drawIds Draw identifiers user buys ticket for.
    /// @param tickets list of uint120 packed tickets. Needs to be of same length as `drawIds`.
    /// @param frontend Address of a frontend operator selling the ticket.
    /// @param referrer The address of a referrer.
    /// @return ticketIds List of minted ticket identifiers.
    function buyTickets(
        uint128[] calldata drawIds,
        uint120[] calldata tickets,
        address frontend,
        address referrer
    )
        external
        returns (uint256[] memory ticketIds);

    /// @dev Transfers all unclaimed fees to frontend operator.
    /// @return amountClaimed Amount of tokens claimed to the frontend operator.
    function claimFrontendFees() external returns (uint256 amountClaimed);

    /// @dev Transfer all winnings to `msg.sender` for the winning tickets.
    /// It reverts in case of non winning ticket.
    /// Only ticket owner can claim win, if any of the tickets is not owned by `msg.sender` it will revert.
    /// @param ticketIds List of ids of the tickets being claimed.
    /// @return claimedAmount Amount of reward tokens claimed to `msg.sender`.
    function claimWinningTickets(uint256[] calldata ticketIds) external returns (uint256 claimedAmount);

    /// @dev checks claimable amount for specific ticket.
    /// @param ticketId Id of the ticket.
    /// @return claimableAmount Amount that can be claimed with this ticket.
    /// @return winTier Tier of the winning ticket (selectionSize for jackpot).
    function claimable(uint256 ticketId) external view returns (uint256 claimableAmount, uint8 winTier);

    /// @dev Starts draw process. Requests a random number from `randomNumberSource`.
    function executeDraw() external;

    /// @dev Rescues tokens from the contract. In case of rewardToken, rescue amount is limited.
    /// Reward token can be rescued if:
    ///  - more than 1 year of draws passed
    ///  - balance of the contract is bigger than MAX_POT
    /// @param token Address of the token contract.
    /// @param to Address to send tokens to.
    /// @param amount Amount of tokens to rescue.
    function rescueTokens(IERC20 token, address to, uint256 amount) external;
}
