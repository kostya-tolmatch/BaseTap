// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/TapFactory.sol";
import "../src/TapRegistry.sol";
import "../src/TapExecutor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TapFactoryTest is Test {
    TapFactory public factory;
    address public owner = address(1);
    address public user = address(2);

    function setUp() public {
        TapFactory implementation = new TapFactory();
        bytes memory initData = abi.encodeWithSelector(
            TapFactory.initialize.selector,
            address(this)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        factory = TapFactory(address(proxy));
    }

    function testDeployRegistry() public {
        address registryProxy = factory.deployRegistry(owner);

        assertTrue(registryProxy != address(0));

        TapRegistry registry = TapRegistry(payable(registryProxy));
        assertEq(registry.owner(), owner);
    }

    function testDeployExecutor() public {
        // First deploy a registry
        address registryProxy = factory.deployRegistry(owner);

        // Then deploy an executor
        address executorProxy = factory.deployExecutor(owner, registryProxy);

        assertTrue(executorProxy != address(0));

        TapExecutor executor = TapExecutor(executorProxy);
        assertEq(executor.owner(), owner);
        assertEq(address(executor.registry()), registryProxy);
    }

    function testFullDeployment() public {
        // Deploy full system
        address registryProxy = factory.deployRegistry(owner);
        address executorProxy = factory.deployExecutor(owner, registryProxy);

        // Verify registry
        TapRegistry registry = TapRegistry(payable(registryProxy));
        assertEq(registry.owner(), owner);
        assertFalse(registry.paused());

        // Verify executor
        TapExecutor executor = TapExecutor(executorProxy);
        assertEq(executor.owner(), owner);
        assertEq(address(executor.registry()), registryProxy);

        // Verify they work together
        // (The actual integration is tested in other test files)
    }

    function testDeployMultipleRegistries() public {
        address registry1 = factory.deployRegistry(owner);
        address registry2 = factory.deployRegistry(user);

        assertTrue(registry1 != address(0));
        assertTrue(registry2 != address(0));
        assertTrue(registry1 != registry2);

        assertEq(TapRegistry(payable(registry1)).owner(), owner);
        assertEq(TapRegistry(payable(registry2)).owner(), user);
    }

    function testDeployMultipleExecutors() public {
        address registry1 = factory.deployRegistry(owner);
        address registry2 = factory.deployRegistry(owner);

        address executor1 = factory.deployExecutor(owner, registry1);
        address executor2 = factory.deployExecutor(owner, registry2);

        assertTrue(executor1 != address(0));
        assertTrue(executor2 != address(0));
        assertTrue(executor1 != executor2);

        assertEq(address(TapExecutor(executor1).registry()), registry1);
        assertEq(address(TapExecutor(executor2).registry()), registry2);
    }

    function testRegistryDeployedEvent() public {
        vm.recordLogs();

        address registryProxy = factory.deployRegistry(owner);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool eventFound = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("RegistryDeployed(address,address)")) {
                eventFound = true;
                break;
            }
        }

        assertTrue(eventFound, "RegistryDeployed event not emitted");
        assertTrue(registryProxy != address(0));
    }

    function testExecutorDeployedEvent() public {
        address registryProxy = factory.deployRegistry(owner);

        vm.recordLogs();

        address executorProxy = factory.deployExecutor(owner, registryProxy);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool eventFound = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("ExecutorDeployed(address,address)")) {
                eventFound = true;
                break;
            }
        }

        assertTrue(eventFound, "ExecutorDeployed event not emitted");
        assertTrue(executorProxy != address(0));
    }

    function testDeployWithDifferentOwners() public {
        address owner1 = address(100);
        address owner2 = address(200);

        address registry1 = factory.deployRegistry(owner1);
        address registry2 = factory.deployRegistry(owner2);

        assertEq(TapRegistry(payable(registry1)).owner(), owner1);
        assertEq(TapRegistry(payable(registry2)).owner(), owner2);
    }
}
