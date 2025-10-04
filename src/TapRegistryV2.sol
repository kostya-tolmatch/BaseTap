// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TapRegistry} from "./TapRegistry.sol";

contract TapRegistryV2 is TapRegistry {
    // Optimized struct with tight packing
    struct TapPresetV2 {
        address recipient;      // 20 bytes
        address asset;          // 20 bytes
        uint96 amount;          // 12 bytes (sufficient for most tokens)
        uint32 cooldown;        // 4 bytes (max ~136 years)
        uint16 dailyLimit;      // 2 bytes (max 65535)
        bool singleUse;         // 1 byte
        bool active;            // 1 byte
    }

    function migrateToV2() external onlyOwner {
        // Migration logic here
    }
}
