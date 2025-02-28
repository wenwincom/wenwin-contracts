// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @dev Thrown when a user attempts to claim tokens before the timeout period has elapsed.
error WaitTimeout();

/// @title IWenWinUSDC Interface
/// @notice Interface for the WenWinUSDC token contract that allows users to claim tokens periodically.
/// @dev This contract implements a time-restricted faucet mechanism for USDC tokens.
interface IWenWinUSDC {
    /// @notice Emitted when a user successfully claims tokens.
    /// @param user Address of the user who claimed tokens.
    /// @param amount Amount of tokens claimed.
    event TokensClaimed(address indexed user, uint256 amount);

    /// @notice Returns the amount of tokens that can be claimed in a single transaction.
    /// @return The current claim amount.
    function claimAmount() external view returns (uint256);

    /// @notice Returns the timeout period between consecutive claims.
    /// @return The current timeout period in seconds.
    function timeout() external view returns (uint256);

    /// @notice Returns the timestamp of the last claim for a given account.
    /// @param account The address to check.
    /// @return The timestamp of the last claim (in Unix time).
    function lastClaimed(address account) external view returns (uint256);

    /// @notice Mints tokens to a specified account.
    /// @dev Only callable by the contract owner.
    /// @param account The address to receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address account, uint256 amount) external;

    /// @notice Updates the claim amount.
    /// @dev Only callable by the contract owner.
    /// @param claimAmount_ The new claim amount.
    function setClaimAmount(uint256 claimAmount_) external;

    /// @notice Updates the timeout period between claims.
    /// @dev Only callable by the contract owner.
    /// @param timeout_ The new timeout period in seconds.
    function setTimeout(uint256 timeout_) external;

    /// @notice Allows a user to claim tokens.
    /// @dev Reverts with WaitTimeout if the timeout period hasn't elapsed since the user's last claim.
    /// @dev Mints the claim amount to the caller and updates their last claim timestamp.
    function claim() external;
}
