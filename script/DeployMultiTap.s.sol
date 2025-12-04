// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/MultiTap.sol";

/// @notice Deploys MultiTap without proxy (stateless contract)
contract DeployMultiTap is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MultiTap multiTap = new MultiTap();
        console.log("MultiTap deployed at:", address(multiTap));

        vm.stopBroadcast();

        return address(multiTap);
    }
}
