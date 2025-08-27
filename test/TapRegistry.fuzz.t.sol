// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./TapRegistry.t.sol";

contract TapRegistryFuzzTest is TapRegistryTest {
    function testFuzz_CreateTap(
        address _recipient,
        uint256 _amount,
        uint32 _cooldown,
        uint16 _dailyLimit
    ) public {
        vm.assume(_recipient != address(0));
        vm.assume(_amount > 0 && _amount < type(uint128).max);
        
        vm.prank(user);
        uint256 tapId = registry.createTap(
            _recipient,
            address(token),
            _amount,
            _cooldown,
            _dailyLimit,
            false
        );
        
        assertEq(registry.tapOwners(tapId), user);
    }

    function testFuzz_ExecuteTap(uint96 _amount) public {
        vm.assume(_amount > 0);
        token.mint(user, _amount);
        
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), _amount, 0, 0, false);
        
        vm.prank(user);
        registry.executeTap(tapId);
        
        assertEq(token.balanceOf(recipient), _amount);
    }
}
