# Polls Smart Contract

A decentralized voting system with support for multi-choice, flexible deadlines, and real-time statistics.

## Deployment to Base Sepolia Testnet

### 1. Prerequisites
Ensure you have some Testnet ETH on Base Sepolia. You can get it from:
- [Base Faucet](https://www.base.org/faucets)
- [Alchemy Faucet](https://www.alchemy.com/faucets/base-sepolia)

### 2. Environment Variables
You need to set your private key for deployment. This project uses Hardhat configuration variables (vars) for security.

Run the following command to set your private key:
```bash
npx hardhat vars set PRIVATE_KEY
```
*(Enter your private key when prompted)*

Optionally, set a custom RPC URL (default is `https://sepolia.base.org`):
```bash
npx hardhat vars set BASE_SEPOLIA_RPC_URL
```

### 3. Deploy
Run the deployment command using Hardhat Ignition:

```bash
npx hardhat ignition deploy ignition/modules/Polls.ts --network baseSepolia
```

### 4. Verify (Optional)
If you want to verify the contract on BaseScan, set your API Key:
```bash
npx hardhat vars set BASESCAN_API_KEY
```
Then run (after deployment):
```bash
npx hardhat ignition verify chain-84532
```

## Contract Features
- **Poll Creation:** Title, description, customizable start/end times.
- **Poll Settings:** Toggle `multiChoice` and `noDeadline`.
- **Statistics:** Unique participant tracking, winner calculation, and user-specific stats.
- **Dynamic Status:** Auto-calculates `Upcoming`, `Open`, `Ended`, or `Cancelled`.
