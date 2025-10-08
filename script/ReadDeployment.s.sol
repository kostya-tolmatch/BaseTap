// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";

contract ReadDeployment is Script {
    function run(string memory network) external view {
        string memory path = string.concat("deployments/", network, ".json");
        string memory json = vm.readFile(path);
        
        console.log("\n=== Deployment Addresses for", network, "===\n");
        console.log(json);
    }
}
