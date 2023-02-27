// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "forge-std/Test.sol";
import "../src/LotteryToken.sol";

contract LotteryTokenTest is Test {
    address public constant OWNER = address(0x111);
    uint256 public constant FIRST_YEAR_INFLATION_PER_DRAW = 1000e18;
    uint256 public constant SECOND_YEAR_INFLATION_PER_DRAW = 500e18;
    uint256 public constant THIRD_YEAR_INFLATION_PER_DRAW = 250e18;

    LotteryToken public lotteryToken;

    address public constant MINT_TO = address(0x123);

    function setUp() public {
        vm.prank(OWNER);
        uint256[] memory inflationRates = new uint256[](3);
        inflationRates[0] = FIRST_YEAR_INFLATION_PER_DRAW;
        inflationRates[1] = SECOND_YEAR_INFLATION_PER_DRAW;
        inflationRates[2] = THIRD_YEAR_INFLATION_PER_DRAW;
        lotteryToken = new LotteryToken(inflationRates);
    }

    function testInflation() public {
        uint256 initialSupply = lotteryToken.INITIAL_SUPPLY();
        uint256 supply = initialSupply;
        assertEq(lotteryToken.totalSupply(), supply);

        vm.startPrank(OWNER);
        for (uint256 i = 0; i < (5 * 52); i++) {
            lotteryToken.mint(MINT_TO, lotteryToken.checkMintableAndIncreaseNextDraw());
            supply += (
                (i < 52)
                    ? FIRST_YEAR_INFLATION_PER_DRAW
                    : ((i < 104) ? SECOND_YEAR_INFLATION_PER_DRAW : THIRD_YEAR_INFLATION_PER_DRAW)
            );

            assertEq(lotteryToken.totalSupply(), supply);
            assertEq(lotteryToken.balanceOf(MINT_TO), (supply - initialSupply));
        }
        vm.stopPrank();
    }

    function testUnauthorizedMinting() public {
        vm.prank(address(0x222));
        vm.expectRevert("Ownable: caller is not the owner");
        lotteryToken.mint(MINT_TO, 1);
    }
}
