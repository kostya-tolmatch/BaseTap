// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/TapRegistry.sol";
import "../src/TapExecutor.sol";
import "../src/BaseTapRegistry.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title UpgradeAll
/// @notice Upgrades all UUPS proxies to new implementations
contract UpgradeAll is Script {
    function run(
        address tapRegistryProxy,
        address tapExecutorProxy,
        address baseTapRegistryProxy
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementations
        TapRegistry newTapRegistry = new TapRegistry();
        console.log("TapRegistry implementation:", address(newTapRegistry));

        TapExecutor newTapExecutor = new TapExecutor();
        console.log("TapExecutor implementation:", address(newTapExecutor));

        BaseTapRegistry newBaseTapRegistry = new BaseTapRegistry();
        console.log("BaseTapRegistry implementation:", address(newBaseTapRegistry));

        // Upgrade proxies
        if (tapRegistryProxy != address(0)) {
            UUPSUpgradeable(tapRegistryProxy).upgradeToAndCall(
                address(newTapRegistry),
                ""
            );
            console.log("TapRegistry upgraded at:", tapRegistryProxy);
        }

        if (tapExecutorProxy != address(0)) {
            UUPSUpgradeable(tapExecutorProxy).upgradeToAndCall(
                address(newTapExecutor),
                ""
            );
            console.log("TapExecutor upgraded at:", tapExecutorProxy);
        }

        if (baseTapRegistryProxy != address(0)) {
            UUPSUpgradeable(baseTapRegistryProxy).upgradeToAndCall(
                address(newBaseTapRegistry),
                ""
            );
            console.log("BaseTapRegistry upgraded at:", baseTapRegistryProxy);
        }

        vm.stopBroadcast();
    }
}
