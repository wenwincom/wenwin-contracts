// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "test/RNSourceControllerMock.sol";
import "test/TestHelpers.sol";
import "test/RNSource.sol";

contract RNSourceControllerTest is Test {
    RNSourceControllerMock public sourceController;
    RNSource public source1;
    RNSource public source2;

    function setUp() public {
        sourceController = new RNSourceControllerMock();

        source1 = new RNSource(address(sourceController));
        source2 = new RNSource(address(sourceController));

        assertEq(address(sourceController.source()), address(0));
        sourceController.initSource(source1);
        assertEq(address(sourceController.source()), address(source1));

        vm.mockCall(
            address(source1), abi.encodeWithSelector(IRNSourceConsumer.onRandomNumberFulfilled.selector), abi.encode(0)
        );

        vm.mockCall(
            address(source2), abi.encodeWithSelector(IRNSourceConsumer.onRandomNumberFulfilled.selector), abi.encode(0)
        );
    }

    function testRetryFailsBeforeRequestDelayThresholdIsReached() public {
        sourceController.request();

        vm.warp(block.timestamp + sourceController.maxRequestDelay());
        vm.expectRevert(CurrentRequestStillActive.selector);
        sourceController.retry();
    }

    function testRetryFailsWhenNoPendingRequest() public {
        vm.expectRevert(CannotRetrySuccessfulRequest.selector);
        sourceController.retry();
    }

    function testSwapSourceFailsWithNonOwnerInvocation() public {
        vm.prank(address(123_123));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sourceController.swapSource(source2);
    }

    function testSwapSourceFailsWithZeroAddress() public {
        vm.expectRevert(RNSourceZeroAddress.selector);
        sourceController.swapSource(IRNSource(address(0)));
    }

    function testSuccessfulSwapSource() public {
        sourceController.request();

        uint256 lastRetryAttempt = block.timestamp + sourceController.maxRequestDelay() + 1;
        vm.warp(lastRetryAttempt);

        vm.expectCall(address(source2), abi.encodeWithSelector(IRNSource.requestRandomNumber.selector));
        sourceController.swapSource(source2);
        assertEq(address(sourceController.source()), address(source2));
    }

    function testOnRandomNumberFulfilledFailedWhenCalledByNonSource() public {
        vm.prank(address(123));
        vm.expectRevert(RandomNumberFulfillmentUnauthorized.selector);
        sourceController.onRandomNumberFulfilled(123);
    }

    function testRequestRandomNumberFailsWhenPendingRequestExists() public {
        sourceController.request();

        vm.expectRevert(PreviousRequestNotFulfilled.selector);
        sourceController.request();
    }

    function testInitSourceFailsWhenAlreadyInitialized() public {
        vm.expectRevert(AlreadyInitialized.selector);
        sourceController.initSource(source2);
    }

    function testInitSourceFailsWithZeroAddress() public {
        vm.expectRevert(RNSourceZeroAddress.selector);
        sourceController.initSource(IRNSource(address(0)));
    }
}
