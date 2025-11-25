// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {TapRegistry} from "../src/TapRegistry.sol";
import {TapExecutor} from "../src/TapExecutor.sol";
import {TapFactory} from "../src/TapFactory.sol";
import {MultiTap} from "../src/MultiTap.sol";
import {BaseTapRegistry} from "../src/BaseTapRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        TapRegistry tapRegistryImpl = new TapRegistry();
        bytes memory tapRegistryInitData = abi.encodeWithSelector(
            TapRegistry.initialize.selector,
            deployer
        );
        ERC1967Proxy tapRegistryProxy = new ERC1967Proxy(
            address(tapRegistryImpl),
            tapRegistryInitData
        );

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

        TapFactory tapFactory = new TapFactory();
        MultiTap multiTap = new MultiTap();

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

        string memory network = vm.envString("NETWORK");
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/deployments/",
            network,
            ".json"
        );

        string memory deployerStr = vm.toString(deployer);
        string memory timestampStr = vm.toString(block.timestamp);

        string memory tapRegistryProxyStr = vm.toString(
            address(tapRegistryProxy)
        );
        string memory tapRegistryImplStr = vm.toString(
            address(tapRegistryImpl)
        );

        string memory tapExecutorProxyStr = vm.toString(
            address(tapExecutorProxy)
        );
        string memory tapExecutorImplStr = vm.toString(
            address(tapExecutorImpl)
        );

        string memory tapFactoryStr = vm.toString(address(tapFactory));
        string memory multiTapStr = vm.toString(address(multiTap));

        string memory baseTapRegistryProxyStr = vm.toString(
            address(baseTapRegistryProxy)
        );
        string memory baseTapRegistryImplStr = vm.toString(
            address(baseTapRegistryImpl)
        );

        string memory json = string.concat(
            '{\n  "network": "',
            network,
            '",\n  "deployer": "',
            deployerStr,
            '",\n  "timestamp": "',
            timestampStr,
            '",\n  "TapRegistry": {\n    "proxy": "',
            tapRegistryProxyStr,
            '",\n    "implementation": "',
            tapRegistryImplStr,
            '"\n  },\n  "TapExecutor": {\n    "proxy": "',
            tapExecutorProxyStr,
            '",\n    "implementation": "',
            tapExecutorImplStr,
            '"\n  },\n  "TapFactory": "',
            tapFactoryStr,
            '",\n  "MultiTap": "',
            multiTapStr,
            '",\n  "BaseTapRegistry": {\n    "proxy": "',
            baseTapRegistryProxyStr,
            '",\n    "implementation": "',
            baseTapRegistryImplStr,
            '"\n  }\n}'
        );

        vm.writeFile(path, json);

        console.log("Deployed to:", network);
        console.log("TapRegistry Proxy:", address(tapRegistryProxy));
        console.log(
            "TapRegistry Implementation:",
            address(tapRegistryImpl)
        );
        console.log("TapExecutor Proxy:", address(tapExecutorProxy));
        console.log(
            "TapExecutor Implementation:",
            address(tapExecutorImpl)
        );
        console.log("TapFactory:", address(tapFactory));
        console.log("MultiTap:", address(multiTap));
        console.log(
            "BaseTapRegistry Proxy:",
            address(baseTapRegistryProxy)
        );
        console.log(
            "BaseTapRegistry Implementation:",
            address(baseTapRegistryImpl)
        );
    }
}
