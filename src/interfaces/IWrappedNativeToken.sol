// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IWrappedNativeToken is IERC20Metadata {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
