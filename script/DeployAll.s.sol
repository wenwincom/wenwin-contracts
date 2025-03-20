// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "script/config/LotteryConfig.sol";
import "script/config/RewardTokenConfig.sol";
import "script/config/RNSourceConfig.sol";
import { WenWinUSDC } from "../src/mocks/WenWinUSDC.sol";

contract DeployAllScript is Script, LotteryConfig, RewardTokenConfig, RNSourceConfig {
    // solhint-disable-next-line no-empty-blocks
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        uint64 nonce = vm.getNonce(deployerPublicKey);
        address lotteryAddress = computeCreateAddress(deployerPublicKey, nonce + 1);

        IERC20 token = getRewardToken();
        uint256 lotteryInitialPot = vm.envUint("LOTTERY_INITIAL_POT");
        token.approve(lotteryAddress, lotteryInitialPot);
        Lottery lottery = getLottery(token);

        lottery.initSource(getGelatoRNSource(address(lottery)));

        vm.stopBroadcast();

        console.log("Lottery deployed at", address(lottery));
    }
}
