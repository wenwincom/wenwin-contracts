// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity ^0.8.19;

import { RNSourceConfig } from "script/config/RNSourceConfig.sol";
import { Script } from "forge-std/Script.sol";

contract GelatoRNSourceScript is Script, RNSourceConfig {
    // solhint-disable-next-line no-empty-blocks
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address authorizedConsumer = vm.envAddress("SOURCE_AUTHORIZED_CONSUMER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        getGelatoRNSource(authorizedConsumer);
        vm.stopBroadcast();
    }
}
