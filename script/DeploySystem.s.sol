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
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy TapRegistry with proxy
        TapRegistry tapRegistryImpl = new TapRegistry();
        bytes memory tapRegistryInitData = abi.encodeWithSelector(
            TapRegistry.initialize.selector,
            deployer
        );
        ERC1967Proxy tapRegistryProxy = new ERC1967Proxy(
            address(tapRegistryImpl),
            tapRegistryInitData
        );

        // 2. Deploy TapExecutor with proxy
        TapExecutor tapExecutorImpl = new TapExecutor();
        bytes memory tapExecutorInitData = abi.encodeWithSelector(
            TapExecutor.initialize.selector,
            deployer,
            address(tapRegistryProxy)
        );
        ERC1967Proxy tapExecutorProxy = new ERC1967Proxy(
            address(tapExecutorImpl),
            tapExecutorInitData
        );

        // 3. Deploy TapFactory with proxy
        TapFactory tapFactoryImpl = new TapFactory();
        bytes memory tapFactoryInitData = abi.encodeWithSelector(
            TapFactory.initialize.selector,
            deployer
        );
        ERC1967Proxy tapFactoryProxy = new ERC1967Proxy(
            address(tapFactoryImpl),
            tapFactoryInitData
        );

        // 4. Deploy MultiTap with proxy
        MultiTap multiTapImpl = new MultiTap();
        bytes memory multiTapInitData = abi.encodeWithSelector(
            MultiTap.initialize.selector,
            deployer
        );
        ERC1967Proxy multiTapProxy = new ERC1967Proxy(
            address(multiTapImpl),
            multiTapInitData
        );

        // 5. Deploy BaseTapRegistry with proxy
        BaseTapRegistry baseTapRegistryImpl = new BaseTapRegistry();
        bytes memory baseTapRegistryInitData = abi.encodeWithSelector(
            BaseTapRegistry.initialize.selector,
            deployer
        );
        ERC1967Proxy baseTapRegistryProxy = new ERC1967Proxy(
            address(baseTapRegistryImpl),
            baseTapRegistryInitData
        );

        vm.stopBroadcast();

        // Save deployment info
        string memory network = vm.envString("NETWORK");
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
            vm.toString(address(tapRegistryProxy)),
            '",\n    "implementation": "',
            vm.toString(address(tapRegistryImpl)),
            '"\n  },\n  "TapExecutor": {\n    "proxy": "',
            vm.toString(address(tapExecutorProxy)),
            '",\n    "implementation": "',
            vm.toString(address(tapExecutorImpl)),
            '"\n  },\n  "TapFactory": {\n    "proxy": "',
            vm.toString(address(tapFactoryProxy)),
            '",\n    "implementation": "',
            vm.toString(address(tapFactoryImpl)),
            '"\n  },\n  "MultiTap": {\n    "proxy": "',
            vm.toString(address(multiTapProxy)),
            '",\n    "implementation": "',
            vm.toString(address(multiTapImpl)),
            '"\n  },\n  "BaseTapRegistry": {\n    "proxy": "',
            vm.toString(address(baseTapRegistryProxy)),
            '",\n    "implementation": "',
            vm.toString(address(baseTapRegistryImpl)),
            '"\n  }\n}'
        );

        vm.writeFile(path, json);

        console.log("\n=== Deployment Complete ===");
        console.log("Network:", network);
        console.log("TapRegistry Proxy:", address(tapRegistryProxy));
        console.log("TapExecutor Proxy:", address(tapExecutorProxy));
        console.log("TapFactory Proxy:", address(tapFactoryProxy));
        console.log("MultiTap Proxy:", address(multiTapProxy));
        console.log("BaseTapRegistry Proxy:", address(baseTapRegistryProxy));
        console.log("Saved to:", path);
    }
}
