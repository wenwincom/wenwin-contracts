// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";

contract ComputeCreateAddress is Script {
    function setUp() public { }

    function run() public view {
        address computedAddress = computeCreateAddress(0xd71f42cFFf1Ad7E722f0785AFeE8da9aD902eB29, 2);
        console.log(computedAddress);
    }
}
