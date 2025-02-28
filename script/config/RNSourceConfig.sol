// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity ^0.8.19;

import { IRNSource } from "src/rnsources/interfaces/IRNSource.sol";
import { API3DaoRNSource } from "src/rnsources/API3DaoRNSource.sol";
import { GelatoRNSource } from "src/rnsources/GelatoRNSource.sol";
import { SupraRNSource } from "src/rnsources/SupraRNSource.sol";
import { VRFv2RNSource } from "src/rnsources/VRFv2RNSource.sol";
import { RNSource } from "test/RNSource.sol";
import { Script } from "forge-std/Script.sol";

contract RNSourceConfig is Script {
    function getVRFv2RNSource(address authorizedConsumer) internal returns (IRNSource rnSource) {
        address vrfWrapper = vm.envAddress("VRFv2_WRAPPER_ADDRESS");
        address linkToken = vm.envAddress("VRFv2_LINK_TOKEN_ADDRESS");

        if (vrfWrapper == address(0) || linkToken == address(0)) {
            rnSource = new RNSource(authorizedConsumer);
        } else {
            uint16 maxAttempts = uint16(vm.envUint("VRFv2_MAX_ATTEMPTS"));
            uint32 gasLimit = uint32(vm.envUint("VRFv2_GAS_LIMIT"));
            rnSource = new VRFv2RNSource(authorizedConsumer, linkToken, vrfWrapper, maxAttempts, gasLimit);
        }
    }

    function getAPI3DaoRNSource(address authorizedConsumer) internal returns (IRNSource rnSource) {
        address _airnodeRrp = vm.envAddress("API3DAO_AIRNODE_RRP");
        address _airnodeProvider = vm.envAddress("API3DAO_AIRNODE_PROVIDER");
        bytes32 _endPointIdUint256 = vm.envBytes32("API3DAO_END_POINT_ID_UINT256");
        address _sponsorWallet = vm.envAddress("API3DAO_SPONSOR_WALLET");

        if (
            _airnodeRrp == address(0) || _airnodeProvider == address(0) || _endPointIdUint256 == "0x0"
                || _sponsorWallet == address(0)
        ) {
            rnSource = new RNSource(authorizedConsumer);
        } else {
            rnSource = new API3DaoRNSource(
                authorizedConsumer, _airnodeRrp, _airnodeProvider, _endPointIdUint256, _sponsorWallet
            );
        }
    }

    function getSupraRNSource(address authorizedConsumer) internal returns (IRNSource rnSource) {
        address supraRouter = vm.envAddress("SUPRA_ROUTER");
        address supraClientWalletAddress = vm.envAddress("SUPRA_CLIENT_WALLET_ADDRESS");
        uint8 supraRequestConfirmations = uint8(vm.envUint("SUPRA_REQUEST_CONFIRMATIONS"));

        if (supraRouter == address(0) || supraClientWalletAddress == address(0)) {
            rnSource = new RNSource(authorizedConsumer);
        } else {
            rnSource =
                new SupraRNSource(authorizedConsumer, supraRouter, supraClientWalletAddress, supraRequestConfirmations);
        }
    }

    function getGelatoRNSource(address authorizedConsumer) internal returns (IRNSource rnSource) {
        address gelatoOperator = vm.envAddress("GELATO_OPERATOR");
        if (gelatoOperator == address(0)) {
            rnSource = new RNSource(authorizedConsumer);
        } else {
            rnSource = new GelatoRNSource(authorizedConsumer, gelatoOperator);
        }
    }
}
