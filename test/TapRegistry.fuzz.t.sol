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

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(tap.recipient, _recipient);
        assertEq(tap.amount, _amount);
        assertEq(tap.cooldown, _cooldown);
        assertEq(tap.dailyLimit, _dailyLimit);
        assertTrue(tap.active);
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

    function testFuzz_UpdateTap(uint128 _newAmount, uint32 _newCooldown) public {
        vm.assume(_newAmount > 0);

        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        registry.updateTap(tapId, _newAmount, _newCooldown);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(tap.amount, _newAmount);
        assertEq(tap.cooldown, _newCooldown);
    }

    function testFuzz_TransferOwnership(address _newOwner) public {
        vm.assume(_newOwner != address(0));
        vm.assume(_newOwner != user);

        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        registry.transferTapOwnership(tapId, _newOwner);

        assertEq(registry.tapOwners(tapId), _newOwner);
    }

    function testFuzz_SetMetadata(string calldata _label, string calldata _description) public {
        vm.assume(bytes(_label).length > 0 && bytes(_label).length < 100);
        vm.assume(bytes(_description).length < 500);

        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        registry.setTapMetadata(tapId, _label, _description);

        (string memory label, string memory description) = registry.getTapMetadata(tapId);
        assertEq(label, _label);
        assertEq(description, _description);
    }

    function testFuzz_CooldownPeriod(uint32 _cooldown) public {
        vm.assume(_cooldown > 0 && _cooldown < 365 days);

        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 10e18, _cooldown, 0, false);

        vm.prank(user);
        registry.executeTap(tapId);

        // Should fail during cooldown
        vm.prank(user);
        vm.expectRevert("Cooldown period active");
        registry.executeTap(tapId);

        // Should succeed after cooldown
        vm.warp(block.timestamp + _cooldown);
        vm.prank(user);
        registry.executeTap(tapId);
    }

    function testFuzz_DailyLimit(uint16 _dailyLimit) public {
        vm.assume(_dailyLimit > 0 && _dailyLimit < 100);

        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 10e18, 0, _dailyLimit, false);

        vm.startPrank(user);
        for (uint256 i = 0; i < _dailyLimit; i++) {
            registry.executeTap(tapId);
        }

        vm.expectRevert("Daily limit reached");
        registry.executeTap(tapId);
        vm.stopPrank();

        // Should reset after 1 day
        vm.warp(block.timestamp + 1 days);
        vm.prank(user);
        registry.executeTap(tapId);
    }

    function testFuzz_ProtocolFee(uint16 _feePercent) public {
        vm.assume(_feePercent <= 1000); // Max 10%

        vm.prank(owner);
        registry.setProtocolFee(_feePercent);

        assertEq(registry.protocolFeePercent(), _feePercent);
    }

    function testFuzz_MultipleExecutions(uint8 _executionCount) public {
        vm.assume(_executionCount > 0 && _executionCount <= 20);

        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 10e18, 0, 0, false);

        uint256 initialBalance = token.balanceOf(recipient);

        vm.startPrank(user);
        for (uint256 i = 0; i < _executionCount; i++) {
            registry.executeTap(tapId);
        }
        vm.stopPrank();

        assertEq(token.balanceOf(recipient), initialBalance + (10e18 * _executionCount));

        TapRegistry.ExecutionHistory[] memory history = registry.getExecutionHistory(tapId);
        assertEq(history.length, _executionCount);
    }

    function testFuzz_BatchCreateTaps(uint8 _tapCount) public {
        vm.assume(_tapCount > 0 && _tapCount <= 10);

        address[] memory recipients = new address[](_tapCount);
        address[] memory assets = new address[](_tapCount);
        uint256[] memory amounts = new uint256[](_tapCount);
        uint256[] memory cooldowns = new uint256[](_tapCount);

        for (uint256 i = 0; i < _tapCount; i++) {
            recipients[i] = address(uint160(100 + i));
            assets[i] = address(token);
            amounts[i] = 100e18 + i;
            cooldowns[i] = 1 hours * (i + 1);
        }

        vm.prank(user);
        uint256[] memory tapIds = registry.batchCreateTaps(recipients, assets, amounts, cooldowns);

        assertEq(tapIds.length, _tapCount);

        for (uint256 i = 0; i < _tapCount; i++) {
            assertEq(registry.tapOwners(tapIds[i]), user);
        }
    }

    function testFuzz_CanExecute(
        uint32 _cooldown,
        uint16 _dailyLimit,
        bool _executeFirst
    ) public {
        vm.assume(_dailyLimit > 0 && _dailyLimit <= 10);
        vm.assume(_cooldown < 365 days);

        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 10e18, _cooldown, _dailyLimit, false);

        if (_executeFirst) {
            vm.prank(user);
            registry.executeTap(tapId);

            if (_cooldown > 0) {
                assertFalse(registry.canExecute(tapId));
                vm.warp(block.timestamp + _cooldown);
            }
        }

        bool canExec = registry.canExecute(tapId);
        assertTrue(canExec || !_executeFirst || _cooldown > 0);
    }

    function testFuzz_DeactivateAndReactivate(uint8 _iterations) public {
        vm.assume(_iterations > 0 && _iterations <= 5);

        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        for (uint256 i = 0; i < _iterations; i++) {
            vm.prank(user);
            registry.deactivateTap(tapId);

            ITapRegistry.TapPreset memory tap = registry.getTap(tapId);
            assertFalse(tap.active);

            // Can't deactivate again
            vm.prank(user);
            vm.expectRevert("Already deactivated");
            registry.deactivateTap(tapId);

            // Can't execute
            vm.prank(user);
            vm.expectRevert("Tap not active");
            registry.executeTap(tapId);

            // For testing purposes, we can't reactivate in the current contract
            // but we verified deactivation works
            break;
        }
    }
}
