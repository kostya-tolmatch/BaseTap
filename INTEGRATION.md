# BaseTap Integration Guide

## Overview

BaseTap is a standard, upgradeable payment tap primitive for Base L2. It provides a secure, configurable payment system with built-in limits, cooldowns, and standardized events.

## Core Concepts

### What is a Tap?

A **tap** is a configured payment endpoint with:
- Target recipient (address receiving payments)
- Token (ERC-20 token or native ETH)
- Amount (fixed payment amount per execution)
- Configurable limits and cooldowns

### Tap Configuration

Each tap can be configured with:

- **recipient**: Address that receives payments (immutable after creation)
- **asset**: Token address (address(0) for native ETH, immutable after creation)
- **amount**: Payment amount per execution (can be updated by owner within global cap constraints)
- **cooldown**: Minimum time between executions (updateable)
- **dailyLimit**: Maximum executions per 24-hour period (set at creation)
- **globalCap**: Lifetime total amount limit (0 = unlimited, set at creation)
- **singleUse**: If true, tap auto-deactivates after first execution (set at creation)

## Tap Lifecycle

### 1. Creation

**For ERC-20 tokens:**
```solidity
uint256 tapId = tapRegistry.createTap(
    recipient,    // address receiving payments
    asset,        // ERC-20 token address
    amount,       // amount per execution
    cooldown,     // seconds between executions
    dailyLimit,   // max executions per day (0 = unlimited)
    singleUse     // deactivate after first use
);
```

**For ERC-20 tokens with global cap:**
```solidity
uint256 tapId = tapRegistry.createTapWithCap(
    recipient,
    asset,
    amount,
    cooldown,
    dailyLimit,
    globalCap,    // lifetime total limit
    singleUse
);
```

**For native ETH:**
```solidity
uint256 tapId = tapRegistry.createTapETH(
    recipient,
    amount,
    cooldown,
    dailyLimit,
    singleUse
);

// With global cap
uint256 tapId = tapRegistry.createTapETHWithCap(
    recipient,
    amount,
    cooldown,
    dailyLimit,
    globalCap,
    singleUse
);
```

**Ownership**: The address that creates a tap becomes its owner.

### 2. Active State

Once created, a tap is **active** and can be executed by anyone who meets the conditions:

- Cooldown period has passed since last execution
- Daily limit not exceeded for current 24h period
- Global cap not reached (if set)
- Tap has not been manually deactivated
- Contract is not paused

**Check if tap can be executed:**
```solidity
bool canExecute = tapRegistry.canExecute(tapId);
```

### 3. Execution

**For ERC-20 tokens:**
```solidity
// Executor must have approved the registry to spend tokens
IERC20(token).approve(address(tapRegistry), amount);
tapRegistry.executeTap(tapId);
```

**For native ETH:**
```solidity
tapRegistry.executeTap{value: amount}(tapId);
```

**Execution behavior**:
- Transfers funds from executor to recipient
- Updates execution timestamp
- Increments daily execution counter
- Tracks total executed amount
- Records execution history
- Auto-deactivates if singleUse or global cap reached

### 4. Updates

**Owner can update amount and cooldown:**
```solidity
tapRegistry.updateTap(
    tapId,
    newAmount,    // new amount per execution (0 = no change)
    newCooldown   // new cooldown in seconds
);
```

**Update constraints**:
- Only tap owner can update
- Tap must be active
- If global cap is set, new amount must satisfy: `totalExecuted + newAmount <= globalCap`
- Cannot change recipient (safety invariant)
- Cannot change asset (safety invariant)

**Update metadata (label and description):**
```solidity
tapRegistry.setTapMetadata(tapId, "Coffee Payment", "Daily coffee fund");
```

### 5. Deactivation

**Manual deactivation by owner:**
```solidity
tapRegistry.deactivateTap(tapId);
```

**Automatic deactivation:**
- After first execution if `singleUse == true`
- When `totalExecuted >= globalCap` (if global cap is set)

**Important**: Once deactivated, a tap cannot be reactivated.

### 6. Ownership Transfer

**Owner can transfer tap to another address:**
```solidity
tapRegistry.transferTapOwnership(tapId, newOwner);
```

**Constraints**:
- Only current owner can transfer
- New owner cannot be address(0)
- Tap must be active

## Safety Invariants

BaseTap enforces the following invariants:

### Immutable Properties

1. **Recipient cannot be changed** after tap creation
2. **Asset cannot be changed** after tap creation
3. **Deactivated taps cannot be reactivated**

### Global Cap Constraints

1. If global cap is set (> 0), the contract ensures:
   - `totalExecuted + amount <= globalCap` before each execution
   - When updating amount: `totalExecuted + newAmount <= globalCap`
   - Tap auto-deactivates when `totalExecuted >= globalCap`

2. Global cap value is fixed at creation and cannot be changed

### Cooldown Behavior

- Cooldown timer starts after each successful execution
- First execution has no cooldown check
- Cooldown can be updated by owner at any time

### Daily Limit Behavior

- Daily limit resets every 24 hours from first execution of the day
- Counter resets when `block.timestamp >= lastDayReset + 1 days`
- Daily limit cannot be changed after creation

### Execution Order

When multiple limits are configured, they are checked in this order:
1. Tap is active
2. Contract is not paused
3. Cooldown period has passed (if set)
4. Global cap not exceeded (if set)
5. Daily limit not exceeded (if set)

## Events

### TapCreated
```solidity
event TapCreated(uint256 indexed tapId, address indexed owner, address recipient);
```
Emitted when a new tap is created.

### TapExecuted
```solidity
event TapExecuted(uint256 indexed tapId, address indexed executor, uint256 amount);
```
Emitted on each successful tap execution.

### TapUpdated
```solidity
event TapUpdated(uint256 indexed tapId, uint256 newAmount, uint256 newCooldown);
```
Emitted when tap configuration is updated.

### TapDeactivated
```solidity
event TapDeactivated(uint256 indexed tapId);
```
Emitted when tap is deactivated (manually or automatically).

### TapGlobalCapSet
```solidity
event TapGlobalCapSet(uint256 indexed tapId, uint256 globalCap);
```
Emitted when a tap is created with a global cap.

### TapGlobalCapReached
```solidity
event TapGlobalCapReached(uint256 indexed tapId);
```
Emitted when total executed amount reaches the global cap.

### TapOwnershipTransferred
```solidity
event TapOwnershipTransferred(uint256 indexed tapId, address indexed from, address indexed to);
```
Emitted when tap ownership is transferred.

## Query Functions

### Get Tap Configuration
```solidity
TapPreset memory tap = tapRegistry.getTap(tapId);
```

Returns the full tap configuration including recipient, asset, amount, cooldown, dailyLimit, singleUse, active status, label, and description.

### Get Tap Metadata
```solidity
(string memory label, string memory description) = tapRegistry.getTapMetadata(tapId);
```

### Get Global Cap
```solidity
uint256 globalCap = tapRegistry.getGlobalCap(tapId);
```

### Get Total Executed
```solidity
uint256 totalExecuted = tapRegistry.getTotalExecuted(tapId);
```

### Check Execution Status
```solidity
bool canExecute = tapRegistry.canExecute(tapId);
```

Returns true if tap can be executed now (considering all limits and cooldowns).

### Get User's Taps
```solidity
uint256[] memory tapIds = tapRegistry.getUserTaps(userAddress);
```

Returns all tap IDs owned by a user.

### Get Active Taps
```solidity
uint256[] memory activeTapIds = tapRegistry.getActiveTaps(userAddress);
```

Returns only active tap IDs owned by a user.

### Get Execution History
```solidity
ExecutionHistory[] memory history = tapRegistry.getExecutionHistory(tapId);
```

Returns array of all executions with timestamp, amount, and executor address.

### Get Execution Count
```solidity
uint256 count = tapRegistry.getExecutionCount(tapId);
```

## Edge Cases and Considerations

### Updating Amount with Global Cap

When a tap has a global cap and has already been executed:
- Increasing amount: Only allowed if `totalExecuted + newAmount <= globalCap`
- Decreasing amount: Always allowed, allows more executions within the cap

Example:
```solidity
// Tap created: amount=100, globalCap=300
// After 2 executions: totalExecuted=200
// Can update to amount=100 (200+100 <= 300) ✓
// Cannot update to amount=150 (200+150 > 300) ✗
// Can update to amount=50 (allows 2 more executions) ✓
```

### Interaction of Multiple Limits

When a tap has cooldown, daily limit, and global cap:
1. Each execution must satisfy cooldown
2. Each execution counts toward daily limit
3. Each execution adds to total executed
4. Tap deactivates when global cap is reached, even if daily limit allows more

### Daily Limit Reset

Daily limit resets based on the timestamp of the first execution in each period:
- First execution at t=0 starts the 24h period
- Period resets at t=86400 (24 hours later)
- Not based on calendar days or UTC midnight

### Native ETH Handling

For ETH taps:
- Executor must send ETH with transaction: `{value: amount}`
- If more ETH is sent than required, excess is refunded to executor
- If insufficient ETH is sent, transaction reverts

### Transfer Ownership Mid-Execution

Ownership can be transferred even after executions have started:
- New owner gains all update and deactivation privileges
- Previous owner loses all control
- Does not affect execution history or total executed
- Does not reset limits or cooldowns

## Contract Addresses

### Base Sepolia
- TapRegistry Proxy: `0xd37B6c90376DF894403A63226F887cc8BD2bDea8`
- TapRegistry Implementation: `0xf07447C2b825ca25BeED053Ec590343C2550933A`

### Base Mainnet
- TapRegistry Proxy: (to be deployed)
- TapRegistry Implementation: (to be deployed)

## Security Considerations

1. **Recipient Immutability**: Recipients cannot be changed after creation. This prevents malicious updates that redirect payments.

2. **Asset Immutability**: Token addresses cannot be changed. Prevents bait-and-switch attacks.

3. **Global Cap Protection**: The contract enforces that amount updates respect remaining capacity under the global cap.

4. **Reentrancy Protection**: All state-changing functions use reentrancy guards.

5. **Pausability**: Contract owner can pause all executions in emergencies.

6. **No Funds Held**: Registry doesn't hold funds except during execution. Payments are atomic transfers.

## Integration Example

```solidity
// 1. Deploy or connect to TapRegistry
ITapRegistry tapRegistry = ITapRegistry(REGISTRY_ADDRESS);

// 2. Create a tap for USDC donations
address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base mainnet
uint256 tapId = tapRegistry.createTapWithCap(
    donationRecipient,
    USDC,
    10e6,        // 10 USDC per donation
    1 hours,     // 1 hour cooldown
    10,          // max 10 donations per day
    1000e6,      // 1000 USDC lifetime cap
    false        // not single-use
);

// 3. Set metadata
tapRegistry.setTapMetadata(
    tapId,
    "OSS Project Donations",
    "Support our open source development"
);

// 4. Users execute the tap
IERC20(USDC).approve(address(tapRegistry), 10e6);
tapRegistry.executeTap(tapId);

// 5. Monitor execution
uint256 totalRaised = tapRegistry.getTotalExecuted(tapId);
ExecutionHistory[] memory donations = tapRegistry.getExecutionHistory(tapId);
```

## Support

For questions and issues:
- GitHub: https://github.com/kostya-tolmatch/BaseTap
- Deployed contracts: See `deployments/` folder
