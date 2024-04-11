// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "script/config/RNSourceConfig.sol";
import "src/rnsources/VRFv2RNSource.sol";

contract API3DaoRNSourceScript is Script, RNSourceConfig {
    // solhint-disable-next-line no-empty-blocks
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address authorizedConsumer = vm.envAddress("SOURCE_AUTHORIZED_CONSUMER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);
        getAPI3DaoRNSource(authorizedConsumer);
        vm.stopBroadcast();
    }
}
