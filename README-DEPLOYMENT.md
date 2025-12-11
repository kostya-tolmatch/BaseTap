# BaseTap Deployment Guide

## Architecture

### All Contracts Use UUPS Proxy Pattern (Upgradeable)

All BaseTap contracts are deployed with **ERC1967 UUPS proxies** for upgradeability:

- **TapRegistry** - Core registry for payment taps
- **TapExecutor** - Batch executor for multiple taps
- **TapFactory** - Factory for creating tap configurations
- **MultiTap** - Payment splitting utility
- **BaseTapRegistry** - Base L2-specific registry features

Each contract has:
- **Proxy address** - Persistent address for user interactions
- **Implementation address** - Upgradeable logic contract

## Deployment Scripts

### Full System Deployment

Deploy all 5 contracts with proxies:

```bash
# Deploy to Base Sepolia testnet
NETWORK=base-sepolia forge script script/DeploySystem.s.sol:DeploySystem \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast --verify

# Deploy to Base mainnet
NETWORK=base forge script script/DeploySystem.s.sol:DeploySystem \
  --rpc-url $BASE_RPC_URL \
  --broadcast --verify
```

### Individual Contract Deployment

Deploy single contracts:

```bash
# TapRegistry
forge script script/DeployTapRegistry.s.sol:DeployTapRegistry \
  --rpc-url $RPC_URL --broadcast

# TapFactory
forge script script/DeployTapFactory.s.sol:DeployTapFactory \
  --rpc-url $RPC_URL --broadcast

# MultiTap
forge script script/DeployMultiTap.s.sol:DeployMultiTap \
  --rpc-url $RPC_URL --broadcast

# BaseTapRegistry
forge script script/DeployBaseTapRegistry.s.sol:DeployBaseTapRegistry \
  --rpc-url $RPC_URL --broadcast
```

## GitHub Actions Deployment

### Setup Required Secrets

Add these secrets to your GitHub repository:

- `PRIVATE_KEY` - Deployer wallet private key
- `BASE_RPC_URL` - Base mainnet RPC URL
- `BASE_SEPOLIA_RPC_URL` - Base Sepolia testnet RPC URL
- `BASESCAN_API_KEY` - Basescan API key for contract verification

### Deploy via GitHub Actions

1. Go to **Actions** tab in GitHub repository
2. Select **Deploy** workflow
3. Click **Run workflow**
4. Configure deployment:
   - **Network**: `base-sepolia` (testnet) or `base` (mainnet)
   - **Action**:
     - `deploy-all` - Deploy entire system (5 contracts)
     - `deploy-multitap` - Deploy MultiTap only
     - `deploy-tapfactory` - Deploy TapFactory only
     - `deploy-basetapregistry` - Deploy BaseTapRegistry only

5. Click **Run workflow** to start deployment

### What Happens During Deployment

1. ✅ Build all contracts
2. ✅ Deploy implementations
3. ✅ Deploy proxies with initialization
4. ✅ Verify contracts on Basescan
5. ✅ Save addresses to `deployments/<network>.json`
6. ✅ Commit deployment file to repository
7. ✅ Generate deployment summary with Basescan links

## Current Deployments

### Base Sepolia (Testnet)

Deployed: December 11, 2025

| Contract | Proxy Address | Implementation |
|----------|---------------|----------------|
| **TapRegistry** | [`0x358E5138a036d8ED587Ae36aFA2F1FFBAED350c7`](https://sepolia.basescan.org/address/0x358E5138a036d8ED587Ae36aFA2F1FFBAED350c7) | [`0xD6f934ea9fa33f00BfFC7786679C6381bbe04770`](https://sepolia.basescan.org/address/0xD6f934ea9fa33f00BfFC7786679C6381bbe04770#code) |
| **TapExecutor** | [`0x47B9C073E6A88aA2C85A45b48a099c156fe91eDC`](https://sepolia.basescan.org/address/0x47B9C073E6A88aA2C85A45b48a099c156fe91eDC) | [`0x946f113db3a14190FE9fF8583Fb20Da06DF368eb`](https://sepolia.basescan.org/address/0x946f113db3a14190FE9fF8583Fb20Da06DF368eb#code) |
| **TapFactory** | [`0x852Ab1575567D2f9d593D33A1f0583113afD7Bc1`](https://sepolia.basescan.org/address/0x852Ab1575567D2f9d593D33A1f0583113afD7Bc1) | [`0x32595b4Ee43D836A91F50cD412c52bF9990C28d3`](https://sepolia.basescan.org/address/0x32595b4Ee43D836A91F50cD412c52bF9990C28d3#code) |
| **MultiTap** | [`0x6c04841B18cDf8CBfa7F9c6b700c09B13Aa7e463`](https://sepolia.basescan.org/address/0x6c04841B18cDf8CBfa7F9c6b700c09B13Aa7e463) | [`0x78421913Bfc07c13bC13ffB0A40B584063b4DE06`](https://sepolia.basescan.org/address/0x78421913Bfc07c13bC13ffB0A40B584063b4DE06#code) |
| **BaseTapRegistry** | [`0xa666C1947a671e771464458D5389b9D004E1D1a1`](https://sepolia.basescan.org/address/0xa666C1947a671e771464458D5389b9D004E1D1a1) | [`0xc2D8b3Fc885F8Bd649adf5b7709374C52A6e0f7b`](https://sepolia.basescan.org/address/0xc2D8b3Fc885F8Bd649adf5b7709374C52A6e0f7b#code) |

**Deployer**: `0x458e29a3F3B9aA53f5A3497026DFA81461eD4917`

### Base Mainnet (Production)

Deployed: December 11, 2025

| Contract | Proxy Address | Implementation |
|----------|---------------|----------------|
| **TapRegistry** | [`0xD2fBbeF9a80884e500f7AE4edc4696B1B326908D`](https://basescan.org/address/0xD2fBbeF9a80884e500f7AE4edc4696B1B326908D) | [`0xb1A4AA05B5786c4Aad1ac3423185783965c7A456`](https://basescan.org/address/0xb1A4AA05B5786c4Aad1ac3423185783965c7A456#code) |
| **TapExecutor** | [`0x8ecA32822E8a984274bA931c130F0C5fB70BBd41`](https://basescan.org/address/0x8ecA32822E8a984274bA931c130F0C5fB70BBd41) | [`0xC5e87ecE32E0500ca21015b68BD53B92C06C1b81`](https://basescan.org/address/0xC5e87ecE32E0500ca21015b68BD53B92C06C1b81#code) |
| **TapFactory** | [`0x13c816beA80cAee9753A48419d17FEd82c7Ca00b`](https://basescan.org/address/0x13c816beA80cAee9753A48419d17FEd82c7Ca00b) | [`0xaD1c6Feb90a0167A926341BA74d9700d958D5DAF`](https://basescan.org/address/0xaD1c6Feb90a0167A926341BA74d9700d958D5DAF#code) |
| **MultiTap** | [`0xe0dE3673b6055D94815C3d1C1ee02BE9b46fDC74`](https://basescan.org/address/0xe0dE3673b6055D94815C3d1C1ee02BE9b46fDC74) | [`0x9879EbA0200e9340A6CfD6fB42664e1C4F409Eb7`](https://basescan.org/address/0x9879EbA0200e9340A6CfD6fB42664e1C4F409Eb7#code) |
| **BaseTapRegistry** | [`0xf86652A0da022426A886c966f397D64135Ce1608`](https://basescan.org/address/0xf86652A0da022426A886c966f397D64135Ce1608) | [`0x2c6517f3dB11b2606faf10f651f8EA2EfD58C0cE`](https://basescan.org/address/0x2c6517f3dB11b2606faf10f651f8EA2EfD58C0cE#code) |

**Deployer**: `0x458e29a3F3B9aA53f5A3497026DFA81461eD4917`

## Contract Verification

Contracts are automatically verified during GitHub Actions deployment. To manually verify:

```bash
# Verify implementation contract
forge verify-contract <IMPLEMENTATION_ADDRESS> <CONTRACT_PATH> \
  --chain-id <CHAIN_ID> \
  --etherscan-api-key $BASESCAN_API_KEY

# Example for TapRegistry on Base Sepolia
forge verify-contract 0xD6f934ea9fa33f00BfFC7786679C6381bbe04770 \
  src/TapRegistry.sol:TapRegistry \
  --chain-id 84532 \
  --etherscan-api-key $BASESCAN_API_KEY
```

**Chain IDs:**
- Base Sepolia: `84532`
- Base Mainnet: `8453`

## Integration

For integration examples and API documentation, see:
- [INTEGRATION.md](./INTEGRATION.md) - Complete integration guide
- [README.md](./README.md) - Project overview

## Security Features

- **UUPS Pattern**: Upgradeable via `upgradeToAndCall()` (owner only)
- **Access Control**: `OwnableUpgradeable` for admin functions
- **Pausable**: Emergency pause mechanism on TapRegistry
- **ReentrancyGuard**: Protection on all state-changing functions
- **Initialization**: One-time initialization via `initializer` modifier

## Support

For issues or questions:
- GitHub Issues: https://github.com/kostya-tolmatch/BaseTap/issues
- Documentation: [INTEGRATION.md](./INTEGRATION.md)
