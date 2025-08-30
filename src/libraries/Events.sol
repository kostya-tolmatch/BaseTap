// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library Events {
    event TapCreated(uint256 indexed tapId, address indexed owner, address recipient, uint256 amount);
    event TapExecuted(uint256 indexed tapId, address indexed executor, uint256 amount);
    event TapUpdated(uint256 indexed tapId, uint256 newAmount, uint256 newCooldown);
    event TapDeactivated(uint256 indexed tapId, address indexed owner);
    event CooldownTriggered(uint256 indexed tapId, uint256 nextAvailable);
    event DailyLimitReset(uint256 indexed tapId);
}
