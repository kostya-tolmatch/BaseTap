// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library TapHelpers {
    function calculateNextExecution(
        uint256 lastExecution,
        uint256 cooldown
    ) internal view returns (uint256) {
        if (cooldown == 0) return block.timestamp;
        return lastExecution + cooldown;
    }

    function isDayPassed(uint256 lastReset) internal view returns (bool) {
        return block.timestamp >= lastReset + 1 days;
    }

    function isExecutionAllowed(
        uint256 lastExecution,
        uint256 cooldown
    ) internal view returns (bool) {
        if (cooldown == 0) return true;
        return block.timestamp >= lastExecution + cooldown;
    }
}
