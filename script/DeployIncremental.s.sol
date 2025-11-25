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
        address tapFactory;
        address multiTap;
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
            addrs.tapRegistryProxy = vm.parseJsonAddress(
                json,
                ".TapRegistry.proxy"
            );
            addrs.tapRegistryImpl = vm.parseJsonAddress(
                json,
                ".TapRegistry.implementation"
            );
            addrs.tapExecutorProxy = vm.parseJsonAddress(
                json,
                ".TapExecutor.proxy"
            );
            addrs.tapExecutorImpl = vm.parseJsonAddress(
                json,
                ".TapExecutor.implementation"
            );
            addrs.tapFactory = vm.parseJsonAddress(json, ".TapFactory");
            addrs.multiTap = vm.parseJsonAddress(json, ".MultiTap");

            try
                vm.parseJsonAddress(json, ".BaseTapRegistry.proxy")
            returns (address addr) {
                addrs.baseTapRegistryProxy = addr;
                addrs.baseTapRegistryImpl = vm.parseJsonAddress(
                    json,
                    ".BaseTapRegistry.implementation"
                );
            } catch {}
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
            console.log("Deploying TapRegistry...");
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
        } else {
            console.log("TapRegistry already deployed");
        }

        if (existing.tapExecutorProxy == address(0)) {
            console.log("Deploying TapExecutor...");
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
        } else {
            console.log("TapExecutor already deployed");
        }

        if (existing.tapFactory == address(0)) {
            console.log("Deploying TapFactory...");
            TapFactory factory = new TapFactory();
            deployed.tapFactory = address(factory);
        } else {
            console.log("TapFactory already deployed");
        }

        if (existing.multiTap == address(0)) {
            console.log("Deploying MultiTap...");
            MultiTap multiTap = new MultiTap();
            deployed.multiTap = address(multiTap);
        } else {
            console.log("MultiTap already deployed");
        }

        if (existing.baseTapRegistryProxy == address(0)) {
            console.log("Deploying BaseTapRegistry...");
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
        } else {
            console.log("BaseTapRegistry already deployed");
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
            '"\n  },\n  "TapFactory": "',
            vm.toString(addrs.tapFactory),
            '",\n  "MultiTap": "',
            vm.toString(addrs.multiTap),
            '",\n  "BaseTapRegistry": {\n    "proxy": "',
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
        console.log("TapRegistry Proxy:", addrs.tapRegistryProxy);
        console.log(
            "TapRegistry Implementation:",
            addrs.tapRegistryImpl
        );
        console.log("TapExecutor Proxy:", addrs.tapExecutorProxy);
        console.log(
            "TapExecutor Implementation:",
            addrs.tapExecutorImpl
        );
        console.log("TapFactory:", addrs.tapFactory);
        console.log("MultiTap:", addrs.multiTap);
        console.log(
            "BaseTapRegistry Proxy:",
            addrs.baseTapRegistryProxy
        );
        console.log(
            "BaseTapRegistry Implementation:",
            addrs.baseTapRegistryImpl
        );
    }
}
