// SPDX-License-Identifier: MIT
/// @title TapRegistry
pragma solidity 0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
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
    PausableUpgradeable,
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
        __Pausable_init();
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
            active: true,
            label: "",
            description: ""
        });

        tapOwners[tapId] = msg.sender;
        emit TapCreated(tapId, msg.sender, recipient);

        return tapId;
    }

    function executeTap(uint256 tapId) external payable nonReentrant whenNotPaused {
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
        _executionHistory[tapId].push(ExecutionHistory({
            timestamp: block.timestamp,
            amount: tap.amount,
            executor: msg.sender
        }));

        if (tap.singleUse) {
            tap.active = false;
            emit TapDeactivated(tapId);
        }
    }

    function getTap(uint256 tapId) external view returns (TapPreset memory) {
        return _taps[tapId];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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
            active: true,
            label: "",
            description: ""
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

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    uint256 public protocolFeePercent;
    address public feeCollector;

    event FeeCollected(uint256 indexed tapId, uint256 amount);
    event FeeUpdated(uint256 newFeePercent);

    function setProtocolFee(uint256 feePercent) external onlyOwner {
        require(feePercent <= 1000, "Fee too high"); // Max 10%
        protocolFeePercent = feePercent;
        emit FeeUpdated(feePercent);
    }

    function setFeeCollector(address collector) external onlyOwner {
        require(collector != address(0), "Invalid collector");
        feeCollector = collector;
    }

    function getUserTaps(address user) external view returns (uint256[] memory) {
        uint256 count;
        for (uint256 i = 1; i <= _tapCounter; ) {
            if (tapOwners[i] == user) count++;
            unchecked { ++i; }
        }

        uint256[] memory userTapIds = new uint256[](count);
        uint256 index;
        for (uint256 i = 1; i <= _tapCounter; ) {
            if (tapOwners[i] == user) {
                userTapIds[index] = i;
                unchecked { ++index; }
            }
            unchecked { ++i; }
        }

        return userTapIds;
    }

    function getActiveTaps(address user) external view returns (uint256[] memory) {
        uint256 count;
        for (uint256 i = 1; i <= _tapCounter; ) {
            if (tapOwners[i] == user && _taps[i].active) count++;
            unchecked { ++i; }
        }

        uint256[] memory activeTapIds = new uint256[](count);
        uint256 index;
        for (uint256 i = 1; i <= _tapCounter; ) {
            if (tapOwners[i] == user && _taps[i].active) {
                activeTapIds[index] = i;
                unchecked { ++index; }
            }
            unchecked { ++i; }
        }

        return activeTapIds;
    }

    function canExecute(uint256 tapId) external view returns (bool) {
        TapPreset storage tap = _taps[tapId];
        if (!tap.active) return false;
        if (paused()) return false;
        
        if (tap.cooldown > 0) {
            if (block.timestamp < _lastExecution[tapId] + tap.cooldown) {
                return false;
            }
        }

        if (tap.dailyLimit > 0) {
            if (block.timestamp < _lastDayReset[tapId] + 1 days) {
                if (_dailyExecutions[tapId] >= tap.dailyLimit) {
                    return false;
                }
            }
        }

        return true;
    }

    mapping(uint256 => string) private _tapLabels;
    mapping(uint256 => string) private _tapDescriptions;

    function setTapMetadata(
        uint256 tapId,
        string calldata label,
        string calldata description
    ) external {
        require(tapOwners[tapId] == msg.sender, "Not owner");
        _tapLabels[tapId] = label;
        _tapDescriptions[tapId] = description;
    }

    function getTapMetadata(uint256 tapId) external view returns (
        string memory label,
        string memory description
    ) {
        return (_tapLabels[tapId], _tapDescriptions[tapId]);
    }

    event TapOwnershipTransferred(uint256 indexed tapId, address indexed from, address indexed to);

    function transferTapOwnership(uint256 tapId, address newOwner) external {
        require(tapOwners[tapId] == msg.sender, "Not owner");
        require(newOwner != address(0), "Invalid new owner");
        require(_taps[tapId].active, "Tap not active");

        address oldOwner = tapOwners[tapId];
        tapOwners[tapId] = newOwner;

        emit TapOwnershipTransferred(tapId, oldOwner, newOwner);
    }

    struct ExecutionHistory {
        uint256 timestamp;
        uint256 amount;
        address executor;
    }

    mapping(uint256 => ExecutionHistory[]) private _executionHistory;

    function getExecutionHistory(uint256 tapId) external view returns (ExecutionHistory[] memory) {
        return _executionHistory[tapId];
    }

    function getExecutionCount(uint256 tapId) external view returns (uint256) {
        return _executionHistory[tapId].length;
    }

    event EmergencyWithdraw(address indexed token, uint256 amount, address indexed to);

    function emergencyWithdrawToken(
        address token,
        uint256 amount,
        address to
    ) external onlyOwner {
        require(paused(), "Must be paused");
        require(to != address(0), "Invalid recipient");

        if (token == address(0)) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit EmergencyWithdraw(token, amount, to);
    }

    uint256[44] private __gap;
}
