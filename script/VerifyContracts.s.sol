// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";

contract VerifyContracts is Script {
    function run() external {
        string memory network = vm.envString("NETWORK");
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", network, ".json");

        string memory json = vm.readFile(path);

        address registryImpl = vm.parseJsonAddress(json, ".TapRegistry.implementation");
        address registryProxy = vm.parseJsonAddress(json, ".TapRegistry.proxy");
        address executorImpl = vm.parseJsonAddress(json, ".TapExecutor.implementation");
        address executorProxy = vm.parseJsonAddress(json, ".TapExecutor.proxy");
        address factory = vm.parseJsonAddress(json, ".TapFactory");
        address multiTap = vm.parseJsonAddress(json, ".MultiTap");

        console.log("Verifying contracts on", network);
        console.log("TapRegistry Implementation:", registryImpl);
        console.log("TapRegistry Proxy:", registryProxy);
        console.log("TapExecutor Implementation:", executorImpl);
        console.log("TapExecutor Proxy:", executorProxy);
        console.log("TapFactory:", factory);
        console.log("MultiTap:", multiTap);
    }
}
