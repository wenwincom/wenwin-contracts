// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { WaitTimeout, IWenWinUSDC } from "../interfaces/IWenWinUSDC.sol";

contract WenWinUSDC is ERC20, Ownable2Step, IWenWinUSDC {
    uint256 public override claimAmount;

    uint256 public override timeout;

    mapping(address => uint256) public override lastClaimed;

    constructor(uint256 claimAmount_, uint256 timeout_) ERC20("WenWin USDC", "WWUSDC") Ownable() {
        claimAmount = claimAmount_;
        timeout = timeout_;
    }

    function mint(address account, uint256 amount) external override onlyOwner {
        _mint(account, amount);
    }

    function setClaimAmount(uint256 claimAmount_) external override onlyOwner {
        claimAmount = claimAmount_;
    }

    function setTimeout(uint256 timeout_) external override onlyOwner {
        timeout = timeout_;
    }

    function claim() external override {
        if (block.timestamp < lastClaimed[msg.sender] + timeout) {
            revert WaitTimeout();
        }

        lastClaimed[msg.sender] = block.timestamp;
        _mint(msg.sender, claimAmount);

        emit TokensClaimed(msg.sender, claimAmount);
    }
}
