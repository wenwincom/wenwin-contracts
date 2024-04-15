// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { RNSourceConfig } from "script/config/RNSourceConfig.sol";
import { SupraRNSource } from "src/rnsources/SupraRNSource.sol";
import { IRNSource, RNSourceBase } from "src/rnsources/RNSourceBase.sol";

contract SupraRNSourceScript is Script, RNSourceConfig {
    // solhint-disable-next-line no-empty-blocks
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address authorizedConsumer = vm.envAddress("SOURCE_AUTHORIZED_CONSUMER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        getSupraRNSource(authorizedConsumer);
        vm.stopBroadcast();
    }
}
