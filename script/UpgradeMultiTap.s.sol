// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/MultiTap.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeMultiTap is Script {
    function run(address proxyAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MultiTap newImplementation = new MultiTap();

        console.log("New implementation deployed at:", address(newImplementation));

        UUPSUpgradeable(proxyAddress).upgradeToAndCall(
            address(newImplementation),
            ""
        );

        console.log("Proxy upgraded");

        vm.stopBroadcast();
    }
}
