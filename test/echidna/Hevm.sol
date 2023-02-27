// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.17;

interface Hevm {
    function prank(address) external;

    function warp(uint256) external;
}
