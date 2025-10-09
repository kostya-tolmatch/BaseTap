// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/TapRegistry.sol";
import "../src/TapExecutor.sol";

contract ValidateDeployment is Script {
    function run(address registryProxy, address executorProxy) external view {
        console.log("\n=== Validating Deployment ===\n");
        
        TapRegistry registry = TapRegistry(payable(registryProxy));
        TapExecutor executor = TapExecutor(payable(executorProxy));
        
        // Check registry
        address registryOwner = registry.owner();
        console.log("Registry Owner:", registryOwner);
        console.log("Registry Paused:", registry.paused());
        console.log("Tap Counter:", registry.getTapCounter());
        
        // Check executor
        address executorOwner = executor.owner();
        address executorRegistry = address(executor.registry());
        console.log("\nExecutor Owner:", executorOwner);
        console.log("Executor Registry:", executorRegistry);
        
        require(executorRegistry == registryProxy, "Registry mismatch");
        console.log("\n✅ Deployment validated successfully");
    }
}
