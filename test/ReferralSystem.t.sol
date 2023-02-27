// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./ReferralSystemBase.sol";
import "../src/ReferralSystem.sol";

contract ReferralSystemTest is ReferralSystemBase {
    function setUp() public {
        inflationRates = new uint256[](2);
        inflationRates[0] = 100_000;
        inflationRates[1] = 50_000;
        LotteryToken _lotteryToken = new LotteryToken(inflationRates);

        playersInflationRates = new uint256[](3);
        playersInflationRates[0] = 6250;
        playersInflationRates[1] = 5000;
        playersInflationRates[2] = 0;

        super.setUp(_lotteryToken, playersInflationRates);
    }
}
