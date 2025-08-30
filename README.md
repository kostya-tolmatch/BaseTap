# BaseTap - Payment System for Base
# BaseTap

One-click payment button system for Base network.

## Overview

BaseTap enables instant USDC payments through upgradeable smart contracts on Base.

### Features
- One-click payment execution
- Cooldown mechanisms
- Daily spending limits
- Single-use payment options
- Fully upgradeable architecture

## Setup

```bash
forge install
forge build
forge test
```

## Architecture
- TapRegistry: Upgradeable payment registry
- TapExecutor: Batch execution engine
## Security
- Reentrancy protection
- UUPS upgradeable pattern
## Usage
See deployment scripts for examples
# Contributing
PRs welcome!
## Deployment Addresses
## Testing
`forge test`

## Factory Deployment

Use TapFactory for one-transaction deployment:

```solidity
TapFactory factory = new TapFactory();

// Deploy registry
address registryProxy = factory.deployRegistry(owner);

// Deploy executor
address executorProxy = factory.deployExecutor(owner, registryProxy);
```
