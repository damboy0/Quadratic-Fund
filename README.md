# Quadratic Funding - Deployment & Setup Guide

##  Overview

This directory contains a complete, production-ready Quadratic Funding (QF) smart contract with comprehensive deployment scripts for multiple networks (local, testnet, mainnet).


##  Quick Start

### 1. Prerequisites

```bash
# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
~/.foundry/bin/foundryup
```

### 2. Local Deployment (Recommended for Testing)

```bash
# Terminal 1: Start Anvil local node
anvil

# Terminal 2: Deploy contract
cd /home/damboy/Codes/qudratic-funding/contract
forge script script/DeployQF.s.sol --rpc-url http://localhost:8545 --broadcast

# Or with initial matching pool
DEPLOY_INITIAL_MATCH=10 forge script script/DeployQF.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast
```

### 3. Deploy with Tests

```bash
# Deploy and run comprehensive post-deployment tests
forge script script/DeployAndTest.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast -vv
```

## Environment Setup

### Create .env File

```bash
cp .env.example .env

# Edit .env with your values
# Required: PRIVATE_KEY
# Optional: DEPLOY_INITIAL_MATCH, VERIFY_CONTRACT, etc.
```
## Testing

### Run Unit Tests



```bash
forge test
forge test -vv  # Verbose
forge test --gas-report  # With gas analysis
```

### Run With Deployment Tests

```bash
forge script script/DeployAndTest.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast -vv
```

##  Verification

### Auto-Verification (Etherscan)

```bash
forge script script/DeployQF.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Manual Verification

1. Visit [Etherscan](https://sepolia.etherscan.io) (or network's explorer)
2. Find your contract address
3. Click "Verify & Publish"
4. Paste contract code from `src/QF.sol`
5. Use compiler version 0.8.13
6. Submit verification


## 🔧 Advanced Usage

### Deploy with Custom Parameters

```bash
# Check DeployQF.s.sol for available environment variables
export DEPLOY_INITIAL_MATCH=50  # 50 ETH
export VERIFY_CONTRACT=true
forge script script/DeployQF.s.sol \
  --rpc-url $RPC_URL \
  --broadcast
```

### Deploy to Multiple Networks

```bash
# Script for deploying to all networks
#!/bin/bash
chains=("sepolia" "polygon" "mainnet")
for chain in "${chains[@]}"; do
  echo "Deploying to $chain..."
  forge script script/DeployQF.s.sol \
    --rpc-url $(eval echo \$${chain^^}_RPC_URL) \
    --broadcast --verify
done
```

### View Deployment in Explorer

```bash
# After deployment, construct explorer URL
EXPLORER_URL="https://sepolia.etherscan.io/address/0x..."
echo "View contract: $EXPLORER_URL"
```

## Security Considerations

### Before Production

- [ ] Run full test suite: `forge test`
- [ ] Check gas usage: `forge test --gas-report`
- [ ] Review code for vulnerabilities
- [ ] Consider security audit
- [ ] Test with small amounts first
- [ ] Use hardware wallet for mainnet


## Troubleshooting

### Issue: "Only owner can call this function"

**Solution:** Ensure correct private key is used and matches contract owner address

### Issue: "Insufficient funds"

**Solution:** 
- Testnet: Use faucet to get test ETH
- Local: Anvil provides 10,000 ETH automatically

### Issue: Contract verification fails

**Solution:**
- Verify API key is correct
- Check contract address is accurate
- Ensure compiler version matches
- Try manual verification on Etherscan

### Issue: "Round not active"

**Solution:** Start a round before making contributions:
```bash
cast send $CONTRACT "startRound(uint256)" 604800 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

## Additional Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)
- [ethers.js Documentation](https://docs.ethers.org/)
- [Sepolia Faucet](https://sepoliafaucet.com/)
- [Etherscan API](https://etherscan.io/apis)


## License

See LICENSE file for details

---
