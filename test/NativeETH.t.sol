// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./TapRegistry.t.sol";

contract NativeETHTest is TapRegistryTest {
    function testCreateETHTap() public {
        vm.prank(user);
        uint256 tapId = registry.createTapETH(recipient, 1 ether, 0, 0, false);
        
        ITapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(tap.asset, address(0));
        assertEq(tap.amount, 1 ether);
    }

    function testExecuteETHTap() public {
        vm.deal(user, 10 ether);
        
        vm.prank(user);
        uint256 tapId = registry.createTapETH(recipient, 1 ether, 0, 0, false);
        
        uint256 balanceBefore = recipient.balance;
        
        vm.prank(user);
        registry.executeTap{value: 1 ether}(tapId);
        
        assertEq(recipient.balance, balanceBefore + 1 ether);
    }
}
