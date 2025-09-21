// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./TapRegistry.t.sol";

contract ViewFunctionsTest is TapRegistryTest {
    function testGetUserTaps() public {
        vm.startPrank(user);
        uint256 tap1 = registry.createTap(recipient, address(token), 100e18, 0, 0, false);
        uint256 tap2 = registry.createTap(recipient, address(token), 200e18, 0, 0, false);
        vm.stopPrank();

        uint256[] memory userTaps = registry.getUserTaps(user);
        assertEq(userTaps.length, 2);
        assertEq(userTaps[0], tap1);
        assertEq(userTaps[1], tap2);
    }

    function testCanExecute() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 1 hours, 0, false);

        assertTrue(registry.canExecute(tapId));

        vm.prank(user);
        registry.executeTap(tapId);

        assertFalse(registry.canExecute(tapId));

        vm.warp(block.timestamp + 1 hours);
        assertTrue(registry.canExecute(tapId));
    }
}
