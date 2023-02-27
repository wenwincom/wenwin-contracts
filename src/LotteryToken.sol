// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/interfaces/ILotteryToken.sol";
import "src/LotteryMath.sol";

/// @dev Lottery token contract. The token has a fixed initial supply.
/// Additional tokens can be minted after each draw is finalized. Inflation rates (per draw) are defined for each year.
contract LotteryToken is ILotteryToken, ERC20, Ownable {
    uint256 public constant override INITIAL_SUPPLY = 1_000_000_000e18;

    uint256[] public override inflationRatesPerDrawForEachYear;

    uint128 public override nextDrawToBeMintedFor;

    /// @dev Initializes lottery token with `INITIAL_SUPPLY` pre-minted tokens. Inflation rates per one lottery draw
    /// are specified for each year and the last one is used for all subsequent years.
    /// @param _inflationRatesPerDrawForEachYear The inflation rates per draw for each year
    constructor(uint256[] memory _inflationRatesPerDrawForEachYear) ERC20("Wenwin Lottery", "LOT") {
        inflationRatesPerDrawForEachYear = _inflationRatesPerDrawForEachYear;
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// @dev Currently mintable amount
    function checkMintableAndIncreaseNextDraw() external override returns (uint256 amount) {
        amount = inflationRatesPerDrawForEachYear[LotteryMath.inflationRateIndexForDraw(
            nextDrawToBeMintedFor++, inflationRatesPerDrawForEachYear.length
        )];
    }

    function mint(address account, uint256 amount) external override onlyOwner {
        _mint(account, amount);
    }
}
