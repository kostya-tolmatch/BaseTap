// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {TapRegistry} from "../src/TapRegistry.sol";
import {TapExecutor} from "../src/TapExecutor.sol";
import {TapFactory} from "../src/TapFactory.sol";
import {MultiTap} from "../src/MultiTap.sol";
import {BaseTapRegistry} from "../src/BaseTapRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title DeploySystem
/// @notice Deploys entire BaseTap system (all contracts with UUPS proxies)
contract DeploySystem is Script {
    struct Deployment {
        address tapRegistryProxy;
        address tapRegistryImpl;
        address tapExecutorProxy;
        address tapExecutorImpl;
        address tapFactoryProxy;
        address tapFactoryImpl;
        address multiTapProxy;
        address multiTapImpl;
        address baseTapRegistryProxy;
        address baseTapRegistryImpl;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        Deployment memory deployment = _deployAll(deployer);

        vm.stopBroadcast();

        _saveDeployment(deployment, deployer);
        _logDeployment(deployment);
    }

    function _deployAll(address deployer) internal returns (Deployment memory deployment) {
        // 1. Deploy TapRegistry
        TapRegistry tapRegistryImpl = new TapRegistry();
        ERC1967Proxy tapRegistryProxy = new ERC1967Proxy(
            address(tapRegistryImpl),
            abi.encodeWithSelector(TapRegistry.initialize.selector, deployer)
        );
        deployment.tapRegistryProxy = address(tapRegistryProxy);
        deployment.tapRegistryImpl = address(tapRegistryImpl);

        // 2. Deploy TapExecutor
        TapExecutor tapExecutorImpl = new TapExecutor();
        ERC1967Proxy tapExecutorProxy = new ERC1967Proxy(
            address(tapExecutorImpl),
            abi.encodeWithSelector(TapExecutor.initialize.selector, deployer, address(tapRegistryProxy))
        );
        deployment.tapExecutorProxy = address(tapExecutorProxy);
        deployment.tapExecutorImpl = address(tapExecutorImpl);

        // 3. Deploy TapFactory
        TapFactory tapFactoryImpl = new TapFactory();
        ERC1967Proxy tapFactoryProxy = new ERC1967Proxy(
            address(tapFactoryImpl),
            abi.encodeWithSelector(TapFactory.initialize.selector, deployer)
        );
        deployment.tapFactoryProxy = address(tapFactoryProxy);
        deployment.tapFactoryImpl = address(tapFactoryImpl);

        // 4. Deploy MultiTap
        MultiTap multiTapImpl = new MultiTap();
        ERC1967Proxy multiTapProxy = new ERC1967Proxy(
            address(multiTapImpl),
            abi.encodeWithSelector(MultiTap.initialize.selector, deployer)
        );
        deployment.multiTapProxy = address(multiTapProxy);
        deployment.multiTapImpl = address(multiTapImpl);

        // 5. Deploy BaseTapRegistry
        BaseTapRegistry baseTapRegistryImpl = new BaseTapRegistry();
        ERC1967Proxy baseTapRegistryProxy = new ERC1967Proxy(
            address(baseTapRegistryImpl),
            abi.encodeWithSelector(BaseTapRegistry.initialize.selector, deployer)
        );
        deployment.baseTapRegistryProxy = address(baseTapRegistryProxy);
        deployment.baseTapRegistryImpl = address(baseTapRegistryImpl);
    }

    function _saveDeployment(Deployment memory d, address deployer) internal {
        string memory network = vm.envString("NETWORK");
        string memory path = string.concat(vm.projectRoot(), "/deployments/", network, ".json");

        string memory json = string.concat(
            '{\n  "network": "', network,
            '",\n  "deployer": "', vm.toString(deployer),
            '",\n  "timestamp": "', vm.toString(block.timestamp),
            '",\n  "TapRegistry": {\n    "proxy": "', vm.toString(d.tapRegistryProxy),
            '",\n    "implementation": "', vm.toString(d.tapRegistryImpl),
            '"\n  },\n  "TapExecutor": {\n    "proxy": "', vm.toString(d.tapExecutorProxy),
            '",\n    "implementation": "', vm.toString(d.tapExecutorImpl),
            '"\n  },\n  "TapFactory": {\n    "proxy": "', vm.toString(d.tapFactoryProxy),
            '",\n    "implementation": "', vm.toString(d.tapFactoryImpl),
            '"\n  },\n  "MultiTap": {\n    "proxy": "', vm.toString(d.multiTapProxy),
            '",\n    "implementation": "', vm.toString(d.multiTapImpl),
            '"\n  },\n  "BaseTapRegistry": {\n    "proxy": "', vm.toString(d.baseTapRegistryProxy),
            '",\n    "implementation": "', vm.toString(d.baseTapRegistryImpl),
            '"\n  }\n}'
        );

        vm.writeFile(path, json);
        console.log("Saved to:", path);
    }

    function _logDeployment(Deployment memory d) internal view {
        console.log("\n=== Deployment Complete ===");
        console.log("TapRegistry Proxy:", d.tapRegistryProxy);
        console.log("TapExecutor Proxy:", d.tapExecutorProxy);
        console.log("TapFactory Proxy:", d.tapFactoryProxy);
        console.log("MultiTap Proxy:", d.multiTapProxy);
        console.log("BaseTapRegistry Proxy:", d.baseTapRegistryProxy);
    }
}
