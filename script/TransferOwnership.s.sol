// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TransferOwnership
/// @notice Transfers ownership of TapRegistry proxy to a new owner
/// @dev Use with: NETWORK=base-sepolia NEW_OWNER=0x... PRIVATE_KEY=<current_owner_key> forge script script/TransferOwnership.s.sol --rpc-url $RPC_URL --broadcast
contract TransferOwnership is Script {
    function run() external {
        uint256 currentOwnerKey = vm.envUint("PRIVATE_KEY");
        address newOwner = vm.envAddress("NEW_OWNER");
        string memory network = vm.envString("NETWORK");

        // Load deployment addresses
        string memory path = string.concat(vm.projectRoot(), "/deployments/", network, ".json");
        string memory json = vm.readFile(path);

        address proxyAddress = vm.parseJsonAddress(json, ".TapRegistry.proxy");

        console.log("Network:", network);
        console.log("Proxy address:", proxyAddress);
        console.log("New owner:", newOwner);

        vm.startBroadcast(currentOwnerKey);

        // Transfer ownership
        Ownable(proxyAddress).transferOwnership(newOwner);

        console.log("Ownership transferred to:", newOwner);

        vm.stopBroadcast();
    }
}
