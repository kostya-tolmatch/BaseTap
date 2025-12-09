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

        // Parse all addresses first to avoid nested calls
        address deployer = vm.parseJsonAddress(json, ".deployer");
        address execProxy = vm.parseJsonAddress(json, ".TapExecutor.proxy");
        address execImpl = vm.parseJsonAddress(json, ".TapExecutor.implementation");
        address factProxy = vm.parseJsonAddress(json, ".TapFactory.proxy");
        address factImpl = vm.parseJsonAddress(json, ".TapFactory.implementation");
        address multiProxy = vm.parseJsonAddress(json, ".MultiTap.proxy");
        address multiImpl = vm.parseJsonAddress(json, ".MultiTap.implementation");
        address baseProxy = vm.parseJsonAddress(json, ".BaseTapRegistry.proxy");
        address baseImpl = vm.parseJsonAddress(json, ".BaseTapRegistry.implementation");

        // Build JSON in smaller chunks
        string memory part1 = string.concat(
            '{\n  "network": "', network,
            '",\n  "deployer": "', vm.toString(deployer),
            '",\n  "timestamp": "', vm.toString(block.timestamp), '"'
        );

        string memory part2 = string.concat(
            ',\n  "TapRegistry": {\n    "proxy": "', vm.toString(proxyAddress),
            '",\n    "implementation": "', vm.toString(newImpl), '"\n  }'
        );

        string memory part3 = string.concat(
            ',\n  "TapExecutor": {\n    "proxy": "', vm.toString(execProxy),
            '",\n    "implementation": "', vm.toString(execImpl), '"\n  }'
        );

        string memory part4 = string.concat(
            ',\n  "TapFactory": {\n    "proxy": "', vm.toString(factProxy),
            '",\n    "implementation": "', vm.toString(factImpl), '"\n  }'
        );

        string memory part5 = string.concat(
            ',\n  "MultiTap": {\n    "proxy": "', vm.toString(multiProxy),
            '",\n    "implementation": "', vm.toString(multiImpl), '"\n  }'
        );

        string memory part6 = string.concat(
            ',\n  "BaseTapRegistry": {\n    "proxy": "', vm.toString(baseProxy),
            '",\n    "implementation": "', vm.toString(baseImpl), '"\n  }\n}'
        );

        string memory updatedJson = string.concat(part1, part2, part3, part4, part5, part6);
        vm.writeFile(path, updatedJson);
        console.log("Updated:", path);
    }
}
