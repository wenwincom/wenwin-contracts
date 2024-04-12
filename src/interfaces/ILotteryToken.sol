// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Mint Amount too big.
error InvalidMintAmount();

/// @dev Minting tokens to early.
error MintTooEarly();

/// @dev Interface for the Lottery token.
interface ILotteryToken is IERC20 {
    /// @dev Initial supply minted at the token deployment.
    function INITIAL_SUPPLY() external view returns (uint256 initialSupply);

    /// @dev Maximum number of tokens to mint every year after 2 years.
    function MAX_MINT_PER_YEAR() external view returns (uint256 maxMint);

    /// @return nextMintAt Timestamp when the next mint can happen.
    function nextMintTimestamp() external view returns (uint256 nextMintAt);

    /// @dev Mints `amount` of tokens to the `account`. Can only mint up to `MAX_MINT_PER_YEAR` per year.
    /// First mint must be after 2 years from deployment.
    /// @param account The recipient of tokens
    /// @param amount Number of tokens to be minted
    function mint(address account, uint256 amount) external;

    /// @dev Bunrs 'amount' of tokens from `msg.sender`.
    /// @param amount Number of tokens to burn.
    function burn(uint256 amount) external;
}
