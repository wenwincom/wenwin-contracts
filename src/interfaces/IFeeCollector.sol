// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFeeCollector {
    /// @dev Fees are claimed from the lottery.
    /// @param feeRecipient Address that received the fee.
    /// @param amount Total amount of rewards claimed.
    event ClaimedFees(address indexed feeRecipient, uint256 indexed amount);

    /// @return token Address of the token fees are paid in.
    function feeToken() external view returns (IERC20 token);

    /// @return feeRecipientAddress Address of the fee recipient.
    function feeRecipient() external view returns (address feeRecipientAddress);

    /// @dev Amount of unclaimed fees.
    /// @return unclaimedAmount Number of tokens claimable by the fee recipient.
    function unclaimedFees() external view returns (uint256 unclaimedAmount);

    /// @dev Claims fees to the `feeRecipient`. Callable only by `feeRecipient`.
    /// @return amountClaimed Amount of `feeToken` claimed.
    function claimFees() external returns (uint256 amountClaimed);
}
