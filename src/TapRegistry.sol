// SPDX-License-Identifier: MIT
/// @title TapRegistry
/// @notice Core registry for payment taps on Base L2
/// @dev Upgradeable via UUPS pattern
///
/// TAP LIFECYCLE:
/// 1. CREATION: Owner calls createTap/createTapWithCap to register a new tap
///    - Immutable: recipient, asset
///    - Configurable: amount, cooldown, dailyLimit, globalCap
/// 2. ACTIVE: Tap can be executed by anyone meeting conditions
///    - Cooldown: minimum time between executions
///    - Daily limit: max executions per 24h period
///    - Global cap: lifetime total amount limit (0 = unlimited)
/// 3. EXECUTION: executeTap transfers funds from caller to recipient
///    - Enforces all limits and cooldowns
///    - Tracks execution history and total executed amount
///    - Auto-deactivates on singleUse or global cap reached
/// 4. UPDATES: Owner can updateTap to modify amount/cooldown
///    - Cannot change recipient (safety invariant)
///    - Cannot change asset (safety invariant)
/// 5. DEACTIVATION: Owner can deactivateTap or tap auto-deactivates
///    - Manual: owner calls deactivateTap
///    - Automatic: singleUse after first execution
///    - Automatic: globalCap reached
/// 6. OWNERSHIP: Owner can transfer tap ownership to another address
///
/// SAFETY INVARIANTS:
/// - Recipient address cannot be changed after creation
/// - Asset address cannot be changed after creation
/// - Global cap can only decrease execution count, never increase
/// - Only owner can update/deactivate tap
/// - Deactivated taps cannot be reactivated
///
pragma solidity 0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
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
    mapping(uint256 => uint256) private _totalExecuted;
    uint256 private _tapCounter;

    function initialize(address initialOwner) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        if (initialOwner != msg.sender) {
            _transferOwnership(initialOwner);
        }
    }

    function createTap(
        address recipient,
        address asset,
        uint256 amount,
        uint256 cooldown,
        uint256 dailyLimit,
        bool singleUse
    ) external returns (uint256) {
        return createTapWithCap(recipient, asset, amount, cooldown, dailyLimit, 0, singleUse);
    }

    function createTapWithCap(
        address recipient,
        address asset,
        uint256 amount,
        uint256 cooldown,
        uint256 dailyLimit,
        uint256 globalCap,
        bool singleUse
    ) public returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(asset != address(0), "Invalid asset");
        require(amount > 0, "Invalid amount");
        if (globalCap > 0) {
            require(globalCap >= amount, "Global cap must be >= amount");
        }

        uint256 tapId = ++_tapCounter;

        _taps[tapId] = TapPreset({
            recipient: recipient,
            asset: asset,
            amount: amount,
            cooldown: cooldown,
            dailyLimit: dailyLimit,
            globalCap: globalCap,
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

        if (tap.cooldown > 0 && _lastExecution[tapId] > 0) {
            require(
                block.timestamp >= _lastExecution[tapId] + tap.cooldown,
                "Cooldown period active"
            );
        }

        if (tap.globalCap > 0) {
            require(_totalExecuted[tapId] + tap.amount <= tap.globalCap, "Global cap reached");
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

        _totalExecuted[tapId] += tap.amount;

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

        if (tap.globalCap > 0 && _totalExecuted[tapId] >= tap.globalCap) {
            tap.active = false;
            emit TapGlobalCapReached(tapId);
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

        emit TapUpdated(tapId, newAmount, newCooldown);
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
        return createTapETHWithCap(recipient, amount, cooldown, dailyLimit, 0, singleUse);
    }

    function createTapETHWithCap(
        address recipient,
        uint256 amount,
        uint256 cooldown,
        uint256 dailyLimit,
        uint256 globalCap,
        bool singleUse
    ) public returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        if (globalCap > 0) {
            require(globalCap >= amount, "Global cap must be >= amount");
        }

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
            globalCap: globalCap,
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
            require(recipients[i] != address(0), "Invalid recipient");
            require(assets[i] != address(0), "Invalid asset");
            require(amounts[i] > 0, "Invalid amount");

            uint256 tapId = ++_tapCounter;

            _taps[tapId] = TapPreset({
                recipient: recipients[i],
                asset: assets[i],
                amount: amounts[i],
                cooldown: cooldowns[i],
                dailyLimit: 0,
                globalCap: 0,
                singleUse: false,
                active: true,
                label: "",
                description: ""
            });

            tapOwners[tapId] = msg.sender;
            emit TapCreated(tapId, msg.sender, recipients[i]);

            tapIds[i] = tapId;
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
        
        if (tap.cooldown > 0 && _lastExecution[tapId] > 0) {
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

    function getTotalExecuted(uint256 tapId) external view returns (uint256) {
        return _totalExecuted[tapId];
    }

    uint256[43] private __gap;
}
