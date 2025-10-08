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

## Automated Deployment

### Via GitHub Actions

1. Go to **Actions** tab in your repository
2. Select **Deploy and Save Addresses** workflow
3. Click **Run workflow**
4. Choose network: `base-sepolia` or `base`
5. Click **Run workflow** button

The workflow will:
- Deploy all contracts
- Verify on Basescan
- Save addresses to `deployments/{network}.json`
- Commit addresses back to repo

### Required GitHub Secrets

Add these in **Settings → Secrets and variables → Actions**:

```
PRIVATE_KEY=0x...           # Your deployer private key
BASE_RPC_URL=https://...    # Base mainnet RPC
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=...        # Get from basescan.org
```

### Manual Deployment

```bash
export NETWORK=base-sepolia
forge script script/DeployAndSave.s.sol:DeployAndSave \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --verify
```

### View Deployed Addresses

```bash
cat deployments/base-sepolia.json
```

Or use the script:

```bash
forge script script/ReadDeployment.s.sol:ReadDeployment base-sepolia
```
