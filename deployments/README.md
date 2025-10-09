# Deployment Addresses

This directory contains deployment addresses for all networks.

## Files

- `base-sepolia.json` - Base Sepolia testnet deployment
- `base.json` - Base mainnet deployment

## Format

```json
{
  "network": "base-sepolia",
  "deployer": "0x...",
  "timestamp": "1234567890",
  "TapRegistry": {
    "proxy": "0x...",
    "implementation": "0x..."
  },
  "TapExecutor": {
    "proxy": "0x...",
    "implementation": "0x..."
  },
  "TapFactory": "0x...",
  "MultiTap": "0x..."
}
```

## Usage

Import addresses in your frontend:

```typescript
import deployments from './deployments/base-sepolia.json';

const registryAddress = deployments.TapRegistry.proxy;
```
