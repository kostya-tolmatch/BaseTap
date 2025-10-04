// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/TapRegistry.sol";
import "../src/TapExecutor.sol";
import "../src/TapFactory.sol";
import "../src/MultiTap.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAndSave is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy TapRegistry
        TapRegistry registryImpl = new TapRegistry();
        bytes memory registryInit = abi.encodeWithSelector(
            TapRegistry.initialize.selector,
            deployer
        );
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            registryInit
        );

        // Deploy TapExecutor
        TapExecutor executorImpl = new TapExecutor();
        bytes memory executorInit = abi.encodeWithSelector(
            TapExecutor.initialize.selector,
            deployer,
            address(registryProxy)
        );
        ERC1967Proxy executorProxy = new ERC1967Proxy(
            address(executorImpl),
            executorInit
        );

        // Deploy TapFactory
        TapFactory factory = new TapFactory();

        // Deploy MultiTap
        MultiTap multiTap = new MultiTap();

        vm.stopBroadcast();

        // Save addresses to file
        string memory network = vm.envString("NETWORK");
        string memory json = string.concat(
            '{\n',
            '  "network": "', network, '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "timestamp": "', vm.toString(block.timestamp), '",\n',
            '  "TapRegistry": {\n',
            '    "proxy": "', vm.toString(address(registryProxy)), '",\n',
            '    "implementation": "', vm.toString(address(registryImpl)), '"\n',
            '  },\n',
            '  "TapExecutor": {\n',
            '    "proxy": "', vm.toString(address(executorProxy)), '",\n',
            '    "implementation": "', vm.toString(address(executorImpl)), '"\n',
            '  },\n',
            '  "TapFactory": "', vm.toString(address(factory)), '",\n',
            '  "MultiTap": "', vm.toString(address(multiTap)), '"\n',
            '}'
        );

        string memory path = string.concat("deployments/", network, ".json");
        vm.writeFile(path, json);

        console.log("\n=== Deployment Successful ===");
        console.log("Network:", network);
        console.log("TapRegistry Proxy:", address(registryProxy));
        console.log("TapExecutor Proxy:", address(executorProxy));
        console.log("TapFactory:", address(factory));
        console.log("MultiTap:", address(multiTap));
        console.log("\nAddresses saved to:", path);
    }
}
