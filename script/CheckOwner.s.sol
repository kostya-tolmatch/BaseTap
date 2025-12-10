// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title CheckOwner
/// @notice Checks the owner of TapRegistry proxy
contract CheckOwner is Script {
    function run() external view {
        string memory network = vm.envString("NETWORK");

        // Load deployment addresses
        string memory path = string.concat(vm.projectRoot(), "/deployments/", network, ".json");
        string memory json = vm.readFile(path);

        address proxyAddress = vm.parseJsonAddress(json, ".TapRegistry.proxy");

        console.log("Network:", network);
        console.log("Proxy address:", proxyAddress);

        // Check owner
        address owner = Ownable(proxyAddress).owner();
        console.log("Current owner:", owner);

        // Check if PRIVATE_KEY matches
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address pkAddress = vm.addr(pk);
        console.log("PRIVATE_KEY address:", pkAddress);

        if (owner == pkAddress) {
            console.log("SUCCESS: PRIVATE_KEY matches owner");
        } else {
            console.log("ERROR: PRIVATE_KEY does not match owner");
            console.log("You need to either:");
            console.log("1. Use the private key for address:", owner);
            console.log("2. Or transfer ownership to:", pkAddress);
        }
    }
}
