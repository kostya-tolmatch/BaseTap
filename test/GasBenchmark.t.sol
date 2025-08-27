// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./TapRegistry.t.sol";

contract GasBenchmarkTest is TapRegistryTest {
    function testGas_CreateTap() public {
        vm.prank(user);
        registry.createTap(recipient, address(token), 100e18, 0, 0, false);
    }

    function testGas_ExecuteTap() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);
        
        vm.prank(user);
        registry.executeTap(tapId);
    }

    function testGas_UpdateTap() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);
        
        vm.prank(user);
        registry.updateTap(tapId, 200e18, 1 hours);
    }
}
