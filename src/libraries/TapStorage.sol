// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ITapRegistry} from "../interfaces/ITapRegistry.sol";

library TapStorage {
    bytes32 constant STORAGE_SLOT = keccak256("basetap.tap.registry.storage.v1");

    struct Layout {
        mapping(uint256 => ITapRegistry.TapPreset) taps;
        mapping(uint256 => address) tapOwners;
        mapping(uint256 => uint256) lastExecution;
        mapping(uint256 => uint256) dailyExecutions;
        mapping(uint256 => uint256) lastDayReset;
        uint256 tapCounter;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
