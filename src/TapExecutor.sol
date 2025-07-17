// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ITapRegistry} from "./interfaces/ITapRegistry.sol";

contract TapExecutor is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    ITapRegistry public registry;

    event BatchExecuted(uint256[] tapIds, address indexed executor);

    function initialize(address initialOwner, address _registry) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        registry = ITapRegistry(_registry);
    }

    function executeBatch(uint256[] calldata tapIds) external {
        for (uint256 i; i < tapIds.length; ++i) {
            registry.executeTap(tapIds[i]);
        }

        emit BatchExecuted(tapIds, msg.sender);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
