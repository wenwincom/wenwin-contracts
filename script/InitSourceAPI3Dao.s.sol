// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "script/config/LotteryConfig.sol";
import "script/config/RNSourceConfig.sol";
import "src/Lottery.sol";

contract InitSourceAPI3DaoScript is Script, LotteryConfig, RNSourceConfig {
    // solhint-disable-next-line no-empty-blocks
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ILottery lottery = ILottery(vm.envAddress("LOTTERY_ADDRESS"));
        lottery.initSource(getAPI3DaoRNSource(address(lottery)));

        vm.stopBroadcast();
    }
}
