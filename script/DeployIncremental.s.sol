// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {TapRegistry} from "../src/TapRegistry.sol";
import {TapExecutor} from "../src/TapExecutor.sol";
import {TapFactory} from "../src/TapFactory.sol";
import {MultiTap} from "../src/MultiTap.sol";
import {BaseTapRegistry} from "../src/BaseTapRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployIncremental is Script {
    struct DeploymentAddresses {
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
        string memory network = vm.envString("NETWORK");

        DeploymentAddresses memory existing = readExistingDeployments(
            network
        );

        vm.startBroadcast(deployerPrivateKey);

        DeploymentAddresses memory deployed = deployMissingContracts(
            existing,
            deployer
        );

        vm.stopBroadcast();

        saveDeployments(network, deployed, deployer);

        logDeployments(deployed);
    }

    function parseAddress(string memory json, string memory key)
        internal
        view
        returns (address)
    {
        try vm.parseJsonString(json, key) returns (string memory addrStr) {
            if (bytes(addrStr).length == 0) {
                return address(0);
            }
            return vm.parseAddress(addrStr);
        } catch {
            return address(0);
        }
    }

    function readExistingDeployments(string memory network)
        internal
        view
        returns (DeploymentAddresses memory)
    {
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/deployments/",
            network,
            ".json"
        );

        DeploymentAddresses memory addrs;

        try vm.readFile(path) returns (string memory json) {
            addrs.tapRegistryProxy = parseAddress(
                json,
                ".TapRegistry.proxy"
            );
            addrs.tapRegistryImpl = parseAddress(
                json,
                ".TapRegistry.implementation"
            );
            addrs.tapExecutorProxy = parseAddress(
                json,
                ".TapExecutor.proxy"
            );
            addrs.tapExecutorImpl = parseAddress(
                json,
                ".TapExecutor.implementation"
            );
            addrs.tapFactoryProxy = parseAddress(
                json,
                ".TapFactory.proxy"
            );
            addrs.tapFactoryImpl = parseAddress(
                json,
                ".TapFactory.implementation"
            );
            addrs.multiTapProxy = parseAddress(json, ".MultiTap.proxy");
            addrs.multiTapImpl = parseAddress(
                json,
                ".MultiTap.implementation"
            );
            addrs.baseTapRegistryProxy = parseAddress(
                json,
                ".BaseTapRegistry.proxy"
            );
            addrs.baseTapRegistryImpl = parseAddress(
                json,
                ".BaseTapRegistry.implementation"
            );
        } catch {
            console.log("No existing deployment found, deploying all...");
        }

        return addrs;
    }

    function deployMissingContracts(
        DeploymentAddresses memory existing,
        address deployer
    ) internal returns (DeploymentAddresses memory) {
        DeploymentAddresses memory deployed = existing;

        if (existing.tapRegistryProxy == address(0)) {
            console.log("\nDeploying TapRegistry with proxy...");
            TapRegistry impl = new TapRegistry();
            bytes memory initData = abi.encodeWithSelector(
                TapRegistry.initialize.selector,
                deployer
            );
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(impl),
                initData
            );
            deployed.tapRegistryProxy = address(proxy);
            deployed.tapRegistryImpl = address(impl);
            console.log("  Proxy:", address(proxy));
            console.log("  Implementation:", address(impl));
        } else {
            console.log("\nTapRegistry already deployed at:", existing.tapRegistryProxy);
        }

        if (existing.tapExecutorProxy == address(0)) {
            console.log("\nDeploying TapExecutor with proxy...");
            TapExecutor impl = new TapExecutor();
            bytes memory initData = abi.encodeWithSelector(
                TapExecutor.initialize.selector,
                deployer,
                deployed.tapRegistryProxy
            );
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(impl),
                initData
            );
            deployed.tapExecutorProxy = address(proxy);
            deployed.tapExecutorImpl = address(impl);
            console.log("  Proxy:", address(proxy));
            console.log("  Implementation:", address(impl));
        } else {
            console.log("\nTapExecutor already deployed at:", existing.tapExecutorProxy);
        }

        if (existing.tapFactoryImpl == address(0)) {
            console.log("\nDeploying TapFactory...");
            TapFactory factory = new TapFactory();
            deployed.tapFactoryImpl = address(factory);
            deployed.tapFactoryProxy = address(0);
            console.log("  Address:", address(factory));
        } else {
            console.log("\nTapFactory already deployed at:", existing.tapFactoryImpl);
        }

        if (existing.multiTapImpl == address(0)) {
            console.log("\nDeploying MultiTap...");
            MultiTap multiTap = new MultiTap();
            deployed.multiTapImpl = address(multiTap);
            deployed.multiTapProxy = address(0);
            console.log("  Address:", address(multiTap));
        } else {
            console.log("\nMultiTap already deployed at:", existing.multiTapImpl);
        }

        if (existing.baseTapRegistryProxy == address(0)) {
            console.log("\nDeploying BaseTapRegistry with proxy...");
            BaseTapRegistry impl = new BaseTapRegistry();
            bytes memory initData = abi.encodeWithSelector(
                BaseTapRegistry.initialize.selector,
                deployer
            );
            ERC1967Proxy proxy = new ERC1967Proxy(
                address(impl),
                initData
            );
            deployed.baseTapRegistryProxy = address(proxy);
            deployed.baseTapRegistryImpl = address(impl);
            console.log("  Proxy:", address(proxy));
            console.log("  Implementation:", address(impl));
        } else {
            console.log("\nBaseTapRegistry already deployed at:", existing.baseTapRegistryProxy);
        }

        return deployed;
    }

    function saveDeployments(
        string memory network,
        DeploymentAddresses memory addrs,
        address deployer
    ) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/deployments/",
            network,
            ".json"
        );

        string memory json = string.concat(
            '{\n  "network": "',
            network,
            '",\n  "deployer": "',
            vm.toString(deployer),
            '",\n  "timestamp": "',
            vm.toString(block.timestamp),
            '",\n  "TapRegistry": {\n    "proxy": "',
            vm.toString(addrs.tapRegistryProxy),
            '",\n    "implementation": "',
            vm.toString(addrs.tapRegistryImpl),
            '"\n  },\n  "TapExecutor": {\n    "proxy": "',
            vm.toString(addrs.tapExecutorProxy),
            '",\n    "implementation": "',
            vm.toString(addrs.tapExecutorImpl),
            '"\n  },\n  "TapFactory": {\n    "proxy": "',
            vm.toString(addrs.tapFactoryProxy),
            '",\n    "implementation": "',
            vm.toString(addrs.tapFactoryImpl),
            '"\n  },\n  "MultiTap": {\n    "proxy": "',
            vm.toString(addrs.multiTapProxy),
            '",\n    "implementation": "',
            vm.toString(addrs.multiTapImpl),
            '"\n  },\n  "BaseTapRegistry": {\n    "proxy": "',
            vm.toString(addrs.baseTapRegistryProxy),
            '",\n    "implementation": "',
            vm.toString(addrs.baseTapRegistryImpl),
            '"\n  }\n}'
        );

        vm.writeFile(path, json);
    }

    function logDeployments(DeploymentAddresses memory addrs)
        internal
        pure
    {
        console.log("\n=== Deployment Summary ===");
        console.log("\nTapRegistry:");
        console.log("  Proxy:", addrs.tapRegistryProxy);
        console.log("  Implementation:", addrs.tapRegistryImpl);
        console.log("\nTapExecutor:");
        console.log("  Proxy:", addrs.tapExecutorProxy);
        console.log("  Implementation:", addrs.tapExecutorImpl);
        console.log("\nTapFactory:");
        console.log("  Proxy:", addrs.tapFactoryProxy);
        console.log("  Implementation:", addrs.tapFactoryImpl);
        console.log("\nMultiTap:");
        console.log("  Proxy:", addrs.multiTapProxy);
        console.log("  Implementation:", addrs.multiTapImpl);
        console.log("\nBaseTapRegistry:");
        console.log("  Proxy:", addrs.baseTapRegistryProxy);
        console.log("  Implementation:", addrs.baseTapRegistryImpl);
    }
}
