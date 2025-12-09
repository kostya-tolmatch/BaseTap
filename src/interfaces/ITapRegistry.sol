// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ITapRegistry {
    struct TapPreset {
        address recipient;
        address asset;
        uint256 amount;
        uint256 cooldown;
        uint256 dailyLimit;
        bool singleUse;
        bool active;
        string label;
        string description;
    }

    event TapCreated(uint256 indexed tapId, address indexed owner, address recipient);
    event TapExecuted(uint256 indexed tapId, address indexed executor, uint256 amount);
    event TapUpdated(uint256 indexed tapId, uint256 newAmount, uint256 newCooldown);
    event TapDeactivated(uint256 indexed tapId);
    event TapGlobalCapReached(uint256 indexed tapId);
    event TapGlobalCapSet(uint256 indexed tapId, uint256 globalCap);

    function createTap(
        address recipient,
        address asset,
        uint256 amount,
        uint256 cooldown,
        uint256 dailyLimit,
        bool singleUse
    ) external returns (uint256);

    function executeTap(uint256 tapId) external payable;
}
