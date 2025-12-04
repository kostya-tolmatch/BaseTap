// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/TapFactory.sol";

/// @notice Deploys TapFactory without proxy (stateless factory)
contract DeployTapFactory is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        TapFactory factory = new TapFactory();
        console.log("TapFactory deployed at:", address(factory));

        vm.stopBroadcast();

        return address(factory);
    }
}
