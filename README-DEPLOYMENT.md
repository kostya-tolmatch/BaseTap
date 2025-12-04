# BaseTap Deployment Guide

## Architecture

### Contracts with UUPS Proxy (Upgradeable)
- **TapRegistry** - Stores taps, owners, execution history
- **TapExecutor** - Batch executor for multiple taps
- **BaseTapRegistry** - Payment session registry

### Contracts without Proxy (Stateless)
- **TapFactory** - Factory for deploying TapRegistry/TapExecutor proxies
- **MultiTap** - Payment splitting utility

## Deployment Scripts

### Full System Deployment
```bash
# Deploy entire system to testnet
NETWORK=base-sepolia forge script script/DeploySystem.s.sol:DeploySystem \
  --rpc-url $BASE_SEPOLIA_RPC \
  --broadcast --verify

# Deploy to mainnet
NETWORK=base forge script script/DeploySystem.s.sol:DeploySystem \
  --rpc-url $BASE_RPC \
  --broadcast --verify
```

### Individual Contract Deployment

#### With Proxy (UUPS)
```bash
# TapRegistry
forge script script/DeployTapRegistry.s.sol:DeployTapRegistry --rpc-url $RPC --broadcast

# BaseTapRegistry
forge script script/DeployBaseTapRegistry.s.sol:DeployBaseTapRegistry --rpc-url $RPC --broadcast
```

#### Without Proxy
```bash
# MultiTap
forge script script/DeployMultiTap.s.sol:DeployMultiTap --rpc-url $RPC --broadcast

# TapFactory
forge script script/DeployTapFactory.s.sol:DeployTapFactory --rpc-url $RPC --broadcast
```

### Upgrades

#### Upgrade Single Proxy
```bash
# TapRegistry
forge script script/UpgradeTapRegistry.s.sol:UpgradeTapRegistry \
  --sig "run(address)" <PROXY_ADDRESS> \
  --rpc-url $RPC --broadcast

# TapExecutor
forge script script/UpgradeTapExecutor.s.sol:UpgradeTapExecutor \
  --sig "run(address)" <PROXY_ADDRESS> \
  --rpc-url $RPC --broadcast
```

#### Upgrade All Proxies
```bash
forge script script/UpgradeAll.s.sol:UpgradeAll \
  --sig "run(address,address,address)" \
  <TAPREGISTRY_PROXY> <TAPEXECUTOR_PROXY> <BASETAPREGISTRY_PROXY> \
  --rpc-url $RPC --broadcast
```

## GitHub Actions Deployment

### Setup Secrets
Add these secrets to your GitHub repository:
- `DEPLOYER_PRIVATE_KEY` - Deployer wallet private key
- `BASE_RPC_URL` - Base mainnet RPC URL
- `BASE_SEPOLIA_RPC_URL` - Base Sepolia testnet RPC URL
- `BASESCAN_API_KEY` - Basescan API key for verification

### Trigger Deployment

1. Go to **Actions** tab in GitHub
2. Select **Deploy Contracts** workflow
3. Click **Run workflow**
4. Choose:
   - **Network**: `base-sepolia` or `base`
   - **Action**:
     - `deploy-all` - Deploy entire system
     - `upgrade-all` - Upgrade all proxies
     - `deploy-multitap` - Deploy new MultiTap
     - `deploy-tapfactory` - Deploy new TapFactory
     - `upgrade-tapregistry` - Upgrade TapRegistry
     - etc.
   - **Proxy address**: (only for upgrades)

## Current Deployments

### Base Sepolia
```
TapRegistry Proxy:       0xaD1c6Feb90a0167A926341BA74d9700d958D5DAF
TapExecutor Proxy:       0x9879EbA0200e9340A6CfD6fB42664e1C4F409Eb7
TapFactory:              0xe0dE3673b6055D94815C3d1C1ee02BE9b46fDC74
MultiTap:                0x2c6517f3dB11b2606faf10f651f8EA2EfD58C0cE
BaseTapRegistry:         (not deployed)
```

### Base Mainnet
```
TapRegistry Proxy:       0x68ce71187e8FEC261AF0EA9C158Ca7e02dB11df5
TapExecutor Proxy:       0xfDf6426D915116310d2197d212b0205469Ae6487
TapFactory:              0xb4b5A27f7BEdDf00a45b7435C09054eDae4494a0
MultiTap:                0x0016E793B9C57887fA1f55937719125E4F270382
BaseTapRegistry:         (not deployed)
```

## Next Steps

### Required Upgrades
1. **TapRegistry** - Critical fixes for batchCreateTaps and cooldown
2. **TapExecutor** - Gas optimization
3. **MultiTap** - Redeploy with splitCounter fix

### Missing Deployments
- **BaseTapRegistry** - Not deployed yet

## Verification

After deployment, verify contracts on Basescan:
```bash
forge verify-contract <ADDRESS> <CONTRACT> \
  --chain-id <CHAIN_ID> \
  --etherscan-api-key $BASESCAN_API_KEY
```

## Security Notes

- All proxy contracts use UUPS pattern with `onlyOwner` authorization
- Emergency pause functionality available on TapRegistry
- Emergency withdrawal function for stuck funds
- ReentrancyGuard on all state-changing functions
