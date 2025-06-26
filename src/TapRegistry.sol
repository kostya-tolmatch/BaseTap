// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ITapRegistry} from "./interfaces/ITapRegistry.sol";

contract TapRegistry is ITapRegistry {
    mapping(uint256 => TapPreset) private _taps;
    mapping(uint256 => address) public tapOwners;
    uint256 private _tapCounter;

    function createTap(
        address recipient,
        address asset,
        uint256 amount,
        uint256 cooldown,
        uint256 dailyLimit,
        bool singleUse
    ) external returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(asset != address(0), "Invalid asset");
        require(amount > 0, "Invalid amount");

        uint256 tapId = ++_tapCounter;

        _taps[tapId] = TapPreset({
            recipient: recipient,
            asset: asset,
            amount: amount,
            cooldown: cooldown,
            dailyLimit: dailyLimit,
            singleUse: singleUse,
            active: true
        });

        tapOwners[tapId] = msg.sender;
        emit TapCreated(tapId, msg.sender, recipient);

        return tapId;
    }

    function executeTap(uint256 tapId) external {
        TapPreset storage tap = _taps[tapId];
        require(tap.active, "Tap not active");

        emit TapExecuted(tapId, msg.sender, tap.amount);

        if (tap.singleUse) {
            tap.active = false;
            emit TapDeactivated(tapId);
        }
    }

    function getTap(uint256 tapId) external view returns (TapPreset memory) {
        return _taps[tapId];
    }
}
