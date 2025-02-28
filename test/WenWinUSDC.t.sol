// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { WaitTimeout, IWenWinUSDC } from "../src/interfaces/IWenWinUSDC.sol";
import { WenWinUSDC } from "../src/mocks/WenWinUSDC.sol";
import { Test } from "forge-std/Test.sol";

contract WenWinUSDCTest is Test {
    WenWinUSDC public token;
    uint256 public claimAmount = 100;
    uint256 public timeout = 60;

    function setUp() public {
        vm.warp(timeout);
        token = new WenWinUSDC(claimAmount, timeout);
    }

    function testClaim() public {
        token.claim();
        assertEq(token.balanceOf(address(this)), claimAmount);
    }

    function testClaimWaitTimeout() public {
        token.claim();
        vm.expectRevert(abi.encodeWithSelector(WaitTimeout.selector));
        token.claim();
    }

    function testClaimTimeoutExpired() public {
        token.claim();
        vm.warp(block.timestamp + timeout + 1);
        token.claim();
        assertEq(token.balanceOf(address(this)), claimAmount * 2);
    }

    function testSetClaimAmount() public {
        token.setClaimAmount(200);
        assertEq(token.claimAmount(), 200);
    }

    function testSetTimeout() public {
        token.setTimeout(120);
        assertEq(token.timeout(), 120);
    }

    function testMint() public {
        uint256 amountToMint = 1_000_000;
        token.mint(address(this), amountToMint);
        assertEq(token.balanceOf(address(this)), amountToMint);
    }

    function testMintOwnableUnauthorizedAccount() public {
        vm.startPrank(address(0x1));
        vm.expectRevert("Ownable: caller is not the owner");
        token.mint(address(this), 1);
    }
}
