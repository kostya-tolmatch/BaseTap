// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TapRegistry} from "./TapRegistry.sol";
import {TapExecutor} from "./TapExecutor.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TapFactory {
    event RegistryDeployed(address indexed proxy, address indexed implementation);
    event ExecutorDeployed(address indexed proxy, address indexed implementation);

    function deployRegistry(address owner) external returns (address proxy) {
        TapRegistry implementation = new TapRegistry();
        bytes memory initData = abi.encodeWithSelector(
            TapRegistry.initialize.selector,
            owner
        );
        proxy = address(new ERC1967Proxy(address(implementation), initData));
        emit RegistryDeployed(proxy, address(implementation));
    }

    function deployExecutor(address owner, address registry) external returns (address proxy) {
        TapExecutor implementation = new TapExecutor();
        bytes memory initData = abi.encodeWithSelector(
            TapExecutor.initialize.selector,
            owner,
            registry
        );
        proxy = address(new ERC1967Proxy(address(implementation), initData));
        emit ExecutorDeployed(proxy, address(implementation));
    }
}
