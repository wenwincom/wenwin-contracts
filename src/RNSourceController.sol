// SPDX-License-Identifier: UNLICENSED
// slither-disable-next-line solc-version
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "src/rnsources/interfaces/IRNSource.sol";
import "src/interfaces/IRNSourceController.sol";

/// @dev A contract that controls the list of random number sources and dispatches random number requests to them.
abstract contract RNSourceController is Ownable2Step, IRNSourceController {
    IRNSource public override source;

    uint256 public override lastRequestTimestamp;
    bool public override lastRequestFulfilled = true;
    uint256 public immutable override maxRequestDelay;
    uint256 private constant MAX_REQUEST_DELAY = 5 hours;

    /// @dev Constructs a new random number source controller.
    /// @param _maxRequestDelay The maximum delay between random number request and its fulfillment
    constructor(uint256 _maxRequestDelay) {
        if (_maxRequestDelay > MAX_REQUEST_DELAY) {
            revert MaxRequestDelayTooBig();
        }
        maxRequestDelay = _maxRequestDelay;
    }

    /// @dev Requests a random number from the current random number source.
    function requestRandomNumber() internal {
        if (!lastRequestFulfilled) {
            revert PreviousRequestNotFulfilled();
        }

        requestRandomNumberFromSource();
    }

    function onRandomNumberFulfilled(uint256 randomNumber) external override {
        if (msg.sender != address(source)) {
            revert RandomNumberFulfillmentUnauthorized();
        }

        lastRequestFulfilled = true;

        receiveRandomNumber(randomNumber);
    }

    function receiveRandomNumber(uint256 randomNumber) internal virtual;

    function retry() external override {
        if (lastRequestFulfilled) {
            revert CannotRetrySuccessfulRequest();
        }
        if (block.timestamp - lastRequestTimestamp <= maxRequestDelay) {
            revert CurrentRequestStillActive();
        }

        emit Retry(source);
        requestRandomNumberFromSource();
    }

    function initSource(IRNSource rnSource) external override onlyOwner {
        if (address(rnSource) == address(0)) {
            revert RNSourceZeroAddress();
        }
        if (address(source) != address(0)) {
            revert AlreadyInitialized();
        }

        source = rnSource;
        emit SourceSet(rnSource);
    }

    function swapSource(IRNSource newSource) external override onlyOwner {
        if (address(newSource) == address(0)) {
            revert RNSourceZeroAddress();
        }
        source = newSource;

        emit SourceSet(newSource);

        if (!lastRequestFulfilled) {
            requestRandomNumberFromSource();
        }
    }

    function requestRandomNumberFromSource() private {
        lastRequestTimestamp = block.timestamp;
        lastRequestFulfilled = false;

        source.requestRandomNumber();
    }
}
