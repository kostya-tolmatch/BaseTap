// SPDX-License-Identifier: MIT
/// @title TapRegistry
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

        if (tap.asset == address(0)) {
            require(msg.value >= tap.amount, "Insufficient ETH");
            (bool success, ) = tap.recipient.call{value: tap.amount}("");
            require(success, "ETH transfer failed");
            if (msg.value > tap.amount) {
                (success, ) = msg.sender.call{value: msg.value - tap.amount}("");
                require(success, "Refund failed");
            }
        } else {
        IERC20(tap.asset).safeTransferFrom(msg.sender, tap.recipient, tap.amount);
        }

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

    function updateTap(uint256 tapId, uint256 newAmount, uint256 newCooldown) external {
        require(tapOwners[tapId] == msg.sender, "Not tap owner");
        require(_taps[tapId].active, "Tap not active");

        if (newAmount > 0) {
            _taps[tapId].amount = newAmount;
        }

        _taps[tapId].cooldown = newCooldown;

        emit TapUpdated(tapId);
    }

    function deactivateTap(uint256 tapId) external {
        require(tapOwners[tapId] == msg.sender, "Not tap owner");
        require(_taps[tapId].active, "Already deactivated");

        _taps[tapId].active = false;

        emit TapDeactivated(tapId);
    
}
uint256[44] private __gap;

    receive() external payable {}

    function createTapETH(
        address recipient,
        uint256 amount,
        uint256 cooldown,
        uint256 dailyLimit,
        bool singleUse
    ) external returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");

        uint256 tapId;
        unchecked {
            tapId = ++_tapCounter;
        }

        _taps[tapId] = TapPreset({
            recipient: recipient,
            asset: address(0),
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

    function batchCreateTaps(
        address[] calldata recipients,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata cooldowns
    ) external returns (uint256[] memory tapIds) {
        require(recipients.length == assets.length, "Length mismatch");
        require(assets.length == amounts.length, "Length mismatch");
        require(amounts.length == cooldowns.length, "Length mismatch");

        tapIds = new uint256[](recipients.length);

        for (uint256 i; i < recipients.length; ) {
            tapIds[i] = this.createTap(
                recipients[i],
                assets[i],
                amounts[i],
                cooldowns[i],
                0,
                false
            );
            unchecked { ++i; }
        }
    }
