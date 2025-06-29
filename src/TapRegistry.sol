// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITapRegistry} from "./interfaces/ITapRegistry.sol";

contract TapRegistry is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ITapRegistry
{
    using SafeERC20 for IERC20;

    mapping(uint256 => TapPreset) private _taps;
    mapping(uint256 => address) public tapOwners;
    mapping(uint256 => uint256) private _lastExecution;
    mapping(uint256 => uint256) private _dailyExecutions;
    mapping(uint256 => uint256) private _lastDayReset;
    uint256 private _tapCounter;

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

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

    function executeTap(uint256 tapId) external nonReentrant {
        TapPreset storage tap = _taps[tapId];
        require(tap.active, "Tap not active");

        if (tap.cooldown > 0) {
            require(
                block.timestamp >= _lastExecution[tapId] + tap.cooldown,
                "Cooldown period active"
            );
        }

        _lastExecution[tapId] = block.timestamp;

        if (tap.dailyLimit > 0) {
            if (block.timestamp >= _lastDayReset[tapId] + 1 days) {
                _dailyExecutions[tapId] = 0;
                _lastDayReset[tapId] = block.timestamp;
            }

            require(_dailyExecutions[tapId] < tap.dailyLimit, "Daily limit reached");
            _dailyExecutions[tapId]++;
        }

        IERC20(tap.asset).safeTransferFrom(msg.sender, tap.recipient, tap.amount);

        emit TapExecuted(tapId, msg.sender, tap.amount);

        if (tap.singleUse) {
            tap.active = false;
            emit TapDeactivated(tapId);
        }
    }

    function getTap(uint256 tapId) external view returns (TapPreset memory) {
        return _taps[tapId];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
