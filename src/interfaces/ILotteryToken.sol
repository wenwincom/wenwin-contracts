// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Interface for the Lottery token.
interface ILotteryToken is IERC20 {
    /// @dev Initial supply minted at the token deployment.
    function INITIAL_SUPPLY() external view returns (uint256 initialSupply);

    /// @dev The inflation rates per one draw for each year.
    function inflationRatesPerDrawForEachYear(uint256 index) external view returns (uint256 inflationRate);

    /// @dev Retrieves the unique identifier of the draw we will mint tokens for with the next mint call
    function nextDrawToBeMintedFor() external view returns (uint128 draw);

    /// @dev Currently mintable amount
    function checkMintableAndIncreaseNextDraw() external returns (uint256 amount);

    /// @dev Mints number of tokens for particular draw and assigns them to `account`, increasing the total supply.
    /// Mint is done for the `nextDrawToBeMintedFor`
    /// @param account The recipient of tokens
    /// @param amount Number of tokens to be minted
    function mint(address account, uint256 amount) external;
}
