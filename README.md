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
