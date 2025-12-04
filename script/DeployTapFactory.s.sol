// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../src/TapFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Deploys TapFactory with UUPS proxy
contract DeployTapFactory is Script {
    function run() external returns (address proxy) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        TapFactory implementation = new TapFactory();
        console.log("Implementation deployed at:", address(implementation));

        bytes memory initData = abi.encodeWithSelector(
            TapFactory.initialize.selector,
            deployer
        );

        proxy = address(new ERC1967Proxy(address(implementation), initData));
        console.log("Proxy deployed at:", proxy);

        vm.stopBroadcast();
    }
}
