// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/TapRegistry.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title UpgradeToV2
/// @notice Upgrades TapRegistry to V2 with globalCap support
/// @dev Use with: forge script script/UpgradeToV2.s.sol --rpc-url $RPC_URL --broadcast
contract UpgradeToV2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory network = vm.envString("NETWORK");

        // Load deployment addresses
        string memory path = string.concat(vm.projectRoot(), "/deployments/", network, ".json");
        string memory json = vm.readFile(path);

        address proxyAddress = vm.parseJsonAddress(json, ".TapRegistry.proxy");
        address oldImpl = vm.parseJsonAddress(json, ".TapRegistry.implementation");

        console.log("Network:", network);
        console.log("Proxy address:", proxyAddress);
        console.log("Old implementation:", oldImpl);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        TapRegistry newImplementation = new TapRegistry();
        console.log("New implementation deployed at:", address(newImplementation));

        // Upgrade proxy to new implementation
        UUPSUpgradeable(proxyAddress).upgradeToAndCall(
            address(newImplementation),
            ""
        );

        console.log("Proxy upgraded to V2");

        vm.stopBroadcast();

        // Update deployment file
        _updateDeployment(network, proxyAddress, address(newImplementation));

        console.log("\n=== Upgrade Complete ===");
        console.log("Verify new implementation with:");
        if (keccak256(bytes(network)) == keccak256("base-sepolia")) {
            console.log("forge verify-contract", address(newImplementation), "src/TapRegistry.sol:TapRegistry --chain base-sepolia");
        } else if (keccak256(bytes(network)) == keccak256("base")) {
            console.log("forge verify-contract", address(newImplementation), "src/TapRegistry.sol:TapRegistry --chain base");
        }
    }

    function _updateDeployment(
        string memory network,
        address proxyAddress,
        address newImpl
    ) internal {
        string memory path = string.concat(vm.projectRoot(), "/deployments/", network, ".json");
        string memory json = vm.readFile(path);

        // Parse existing data
        address deployer = vm.parseJsonAddress(json, ".deployer");

        // Build JSON string directly without intermediate variables
        string memory updatedJson = string.concat(
            '{\n  "network": "', network,
            '",\n  "deployer": "', vm.toString(deployer),
            '",\n  "timestamp": "', vm.toString(block.timestamp),
            '",\n  "TapRegistry": {\n    "proxy": "', vm.toString(proxyAddress),
            '",\n    "implementation": "', vm.toString(newImpl),
            '"\n  },\n  "TapExecutor": {\n    "proxy": "',
            vm.toString(vm.parseJsonAddress(json, ".TapExecutor.proxy")),
            '",\n    "implementation": "',
            vm.toString(vm.parseJsonAddress(json, ".TapExecutor.implementation")),
            '"\n  },\n  "TapFactory": {\n    "proxy": "',
            vm.toString(vm.parseJsonAddress(json, ".TapFactory.proxy")),
            '",\n    "implementation": "',
            vm.toString(vm.parseJsonAddress(json, ".TapFactory.implementation")),
            '"\n  },\n  "MultiTap": {\n    "proxy": "',
            vm.toString(vm.parseJsonAddress(json, ".MultiTap.proxy")),
            '",\n    "implementation": "',
            vm.toString(vm.parseJsonAddress(json, ".MultiTap.implementation")),
            '"\n  },\n  "BaseTapRegistry": {\n    "proxy": "',
            vm.toString(vm.parseJsonAddress(json, ".BaseTapRegistry.proxy")),
            '",\n    "implementation": "',
            vm.toString(vm.parseJsonAddress(json, ".BaseTapRegistry.implementation")),
            '"\n  }\n}'
        );

        vm.writeFile(path, updatedJson);
        console.log("Updated:", path);
    }
}
