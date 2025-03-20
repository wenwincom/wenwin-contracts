// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity ^0.8.19;

import { WenWinUSDC } from "../src/mocks/WenWinUSDC.sol";
import { Script } from "forge-std/Script.sol";

contract WenWinUSDCScript is Script {
    // solhint-disable-next-line no-empty-blocks
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        uint256 claimAmount = uint256(vm.envUint("WENWIN_USDC_CLAIM_AMOUNT"));
        uint256 timeout = uint256(vm.envUint("WENWIN_USDC_TIMEOUT"));

        vm.startBroadcast(deployerPrivateKey);

        new WenWinUSDC(claimAmount, timeout);

        vm.stopBroadcast();
    }
}
