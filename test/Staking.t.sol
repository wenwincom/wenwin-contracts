// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./LotteryTestBase.sol";
import "../src/Lottery.sol";
import "../src/LotteryToken.sol";
import "../src/staking/Staking.sol";
import "./TestToken.sol";

contract StakingTest is LotteryTestBaseERC20 {
    IStaking public staking;
    address public constant STAKER = address(69);
    address public constant OWNER = address(70);

    ILotteryToken public stakingToken;

    function setUp() public override {
        super.setUp();
        vm.prank(OWNER);
        stakingToken = new LotteryToken();
        staking = new Staking(lottery, lottery.rewardToken(), stakingToken, "stWW", "stWW");
        vm.prank(rewardsRecipient);
        lottery.changeFeeRecipient(address(staking));

        vm.prank(OWNER);
        stakingToken.transfer(STAKER, 10_000e18);
    }

    function testGetRewardsSingleStaker() public {
        vm.startPrank(STAKER);
        stakingToken.approve(address(staking), 1);
        staking.stake(1);
        buySameTickets(lottery.currentDraw(), uint120(0x0F), address(0), 4);
        uint256 preRewardClaimBalance = rewardToken.balanceOf(STAKER);

        assertEq(staking.earned(STAKER), TICKET_FEE * 4);
        staking.getReward();
        assertEq(rewardToken.balanceOf(STAKER) - preRewardClaimBalance, TICKET_FEE * 4);
    }

    function testGetRewardsMultipleStakersStakePostIncome() public {
        address staker2 = address(420);
        vm.startPrank(STAKER);
        stakingToken.approve(address(staking), 1);
        staking.stake(1);
        buySameTickets(lottery.currentDraw(), uint120(0x0F), address(0), 2);
        vm.stopPrank();

        vm.prank(OWNER);
        stakingToken.transfer(staker2, 1);
        vm.startPrank(staker2);
        stakingToken.approve(address(staking), 1);
        staking.stake(1);

        uint256 preRewardClaimBalanceStaker1 = rewardToken.balanceOf(STAKER);
        uint256 preRewardClaimBalanceStaker2 = rewardToken.balanceOf(staker2);
        staking.getReward();
        vm.stopPrank();
        vm.startPrank(STAKER);
        staking.getReward();

        assertEq(rewardToken.balanceOf(STAKER) - preRewardClaimBalanceStaker1, TICKET_FEE * 2);
        assertEq(rewardToken.balanceOf(staker2), preRewardClaimBalanceStaker2);
    }

    function testGetRewardsMultipleStakersSplit() public {
        address staker2 = address(420);
        vm.startPrank(STAKER);
        stakingToken.approve(address(staking), 1);
        staking.stake(1);
        buySameTickets(lottery.currentDraw(), uint120(0x0F), address(0), 2);
        vm.stopPrank();

        vm.prank(OWNER);
        stakingToken.transfer(staker2, 1);
        vm.startPrank(staker2);
        stakingToken.approve(address(staking), 1);
        staking.stake(1);

        vm.stopPrank();
        vm.startPrank(STAKER);
        buySameTickets(lottery.currentDraw(), uint120(0x0F), address(0), 2);

        uint256 preRewardClaimBalanceStaker1 = rewardToken.balanceOf(STAKER);
        uint256 preRewardClaimBalanceStaker2 = rewardToken.balanceOf(staker2);
        staking.getReward();
        vm.stopPrank();
        vm.startPrank(staker2);
        staking.getReward();

        assertEq(rewardToken.balanceOf(STAKER) - preRewardClaimBalanceStaker1, TICKET_FEE * 3);
        assertEq(rewardToken.balanceOf(staker2) - preRewardClaimBalanceStaker2, TICKET_FEE);
    }

    function testExit() public {
        uint256 stakeAmount = 1;
        vm.startPrank(STAKER);
        stakingToken.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        buySameTickets(lottery.currentDraw(), uint120(0x0F), address(0), 4);

        uint256 preExitRewardTokenBalance = rewardToken.balanceOf(STAKER);
        uint256 preExitStakeTokenBalance = stakingToken.balanceOf(STAKER);
        staking.exit();
        assertEq(rewardToken.balanceOf(STAKER) - preExitRewardTokenBalance, TICKET_FEE * 4);
        assertEq(stakingToken.balanceOf(STAKER) - preExitStakeTokenBalance, stakeAmount);
    }

    function testTransferDoesNotTransferRewards() public {
        address staker2 = address(420);
        vm.startPrank(STAKER);
        stakingToken.approve(address(staking), 1);
        staking.stake(1);
        buySameTickets(lottery.currentDraw(), uint120(0x0F), address(0), 4);
        uint256 preRewardClaimBalance = rewardToken.balanceOf(STAKER);

        staking.transfer(staker2, 1);
        assertEq(staking.earned(STAKER), TICKET_FEE * 4);
        assertEq(staking.earned(staker2), 0);
        staking.getReward();
        assertEq(rewardToken.balanceOf(STAKER) - preRewardClaimBalance, TICKET_FEE * 4);
    }

    function testTransferFromDoesNotTransferRewards() public {
        address staker2 = address(420);
        vm.startPrank(STAKER);
        stakingToken.approve(address(staking), 1);
        staking.stake(1);
        buySameTickets(lottery.currentDraw(), uint120(0x0F), address(0), 4);
        uint256 preRewardClaimBalance = rewardToken.balanceOf(STAKER);

        staking.approve(staker2, 1);
        vm.stopPrank();
        vm.prank(staker2);
        staking.transferFrom(STAKER, staker2, 1);
        assertEq(staking.earned(STAKER), TICKET_FEE * 4);
        assertEq(staking.earned(staker2), 0);
        vm.prank(STAKER);
        staking.getReward();
        assertEq(rewardToken.balanceOf(STAKER) - preRewardClaimBalance, TICKET_FEE * 4);
    }

    function testConstructorZeroAddress() public {
        vm.expectRevert(ZeroAddressInput.selector);
        new Staking(lottery, IERC20(address(0)), stakingToken, "Staked LOT", "stLOT");
        vm.expectRevert(ZeroAddressInput.selector);
        new Staking(lottery, rewardToken, IERC20(address(0)), "Staked LOT", "stLOT");
        vm.expectRevert(ZeroAddressInput.selector);
        new Staking(ILottery(address(0)), rewardToken, stakingToken, "Staked LOT", "stLOT");
    }

    function testStakeWithZeroAmount() public {
        vm.expectRevert(ZeroAmountInput.selector);
        staking.stake(0);
    }

    function testWithdrawWithZeroAmount() public {
        vm.expectRevert(ZeroAmountInput.selector);
        staking.withdraw(0);
    }

    function testWithdrawSendsTokens() public {
        uint256 amount = 123;
        vm.startPrank(STAKER);
        stakingToken.approve(address(staking), amount);
        staking.stake(amount);

        uint256 preWithdrawalBalance = stakingToken.balanceOf(STAKER);
        staking.withdraw(amount);
        assertEq(stakingToken.balanceOf(STAKER) - preWithdrawalBalance, amount);
    }

    function testDelayFirstStake() public {
        assertEq(staking.totalSupply(), 0);
        assertEq(rewardToken.balanceOf(address(staking)), 0);
        assertEq(staking.rewardPerTokenStored(), 0);

        buySameTickets(lottery.currentDraw(), uint120(0x0F), address(0), 4);
        vm.prank(address(staking));
        lottery.claimFees();
        assertEq(staking.totalSupply(), 0);
        assertEq(rewardToken.balanceOf(address(staking)), 4e18);
        assertEq(staking.rewardPerTokenStored(), 0);

        vm.startPrank(STAKER);
        stakingToken.approve(address(staking), 1e18);
        staking.stake(1e18);
        vm.stopPrank();
        assertEq(staking.totalSupply(), 1e18);
        assertEq(rewardToken.balanceOf(address(staking)), 4e18);
        assertEq(staking.rewardPerTokenStored(), 0);

        // buy one ticket and get rewards
        buySameTickets(lottery.currentDraw(), uint120(0x0F), address(0), 1);

        vm.prank(address(staking));
        lottery.claimFees();
        assertEq(staking.totalSupply(), 1e18);
        assertEq(rewardToken.balanceOf(address(staking)), 5e18);
        assertEq(staking.rewardPerTokenStored(), 0);

        vm.prank(STAKER);
        staking.exit();
        assertEq(staking.totalSupply(), 0);
        assertEq(rewardToken.balanceOf(address(staking)), 0);
        assertEq(staking.rewardPerTokenStored(), 5e18);

        buySameTickets(lottery.currentDraw(), uint120(0x0F), address(0), 1);

        vm.prank(address(staking));
        lottery.claimFees();
        assertEq(staking.totalSupply(), 0);
        assertEq(rewardToken.balanceOf(address(staking)), 1e18);
        assertEq(staking.rewardPerTokenStored(), 5e18);
    }
}
