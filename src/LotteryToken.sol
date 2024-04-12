// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "src/interfaces/ILotteryToken.sol";
import "src/LotteryMath.sol";

/// @dev Lottery token contract. The token has a fixed initial supply.
/// Additional tokens can be minted after 2 years. Maximum inflation is 200M tokens per year.
contract LotteryToken is ILotteryToken, ERC20, Ownable2Step {
    uint256 public constant override INITIAL_SUPPLY = 1_000_000_000e18;
    uint256 public constant override MAX_MINT_PER_YEAR = 200_000_000e18;

    uint256 public override nextMintTimestamp;

    /// @dev Initializes lottery token with `INITIAL_SUPPLY` pre-minted tokens
    constructor() ERC20("Wenwin", "WW") {
        nextMintTimestamp = block.timestamp + 2 * 365 days;
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function mint(address account, uint256 amount) external override onlyOwner {
        uint256 currentTime = block.timestamp;
        if (currentTime < nextMintTimestamp) {
            revert MintTooEarly();
        }
        if (amount > MAX_MINT_PER_YEAR) {
            revert InvalidMintAmount();
        }
        nextMintTimestamp = currentTime + 365 days;
        _mint(account, amount);
    }

    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }
}
