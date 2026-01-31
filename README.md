# Yilnes: Multi-Chain Principal Protected RWA Yield Aggregator

> **The First "Upfront Premium" Multi-Chain RWA Yield Aggregator.**
> Institutional-grade yields with immediate solvency protection from Block 1.

![License](https://img.shields.io/badge/license-MIT-green)
![Networks](https://img.shields.io/badge/networks-Mantle%20%7C%20Base-blue)
![Status](https://img.shields.io/badge/status-Deployed-brightgreen)

## 📖 The Problem
DeFi insurance faces a "Cold Start Paradox." Protocols traditionally build insurance funds by taxing *future* profits (e.g., 10% performance fee).
* **The Risk:** If a hack happens in Month 1, the reserve is empty. Early adopters are 100% exposed.
* **The Result:** Users are afraid to provide liquidity to new RWA strategies.

## 💡 The Yilnes Solution
We flip the model. Instead of taxing uncertain future yields, we charge a **Time-Based Premium** at the moment of deposit.
* **Instant Solvency:** Premiums flow directly into the Safety Reserve, ensuring immediate liquidity to cover losses.
* **100% Yield Retention:** Users keep all their upside because they paid for safety upfront.
* **Gamified Risk:** Users choose their term (28 to 365 days) via a slider, paying only for the coverage they need.
* **Multi-Chain Access:** Deploy across multiple networks for maximum liquidity and yield opportunities.

## 🏗️ Tech Stack
* **Networks:** Mantle Sepolia Testnet, Base Sepolia Testnet
* **Contracts:** Solidity, Foundry (Forge), Multi-chain deployment
* **Token Standard:** USDC (6 decimals) - Industry standard stablecoin
* **Frontend:** Next.js 14, TypeScript, Tailwind CSS, Framer Motion
* **Web3:** Wagmi v2, Viem, RainbowKit
* **Assets:** $USDC (USD Coin), Native tokens ($MNT, $ETH)

## 📂 Repository Structure
```bash
├── contracts/           # Foundry Project
│   ├── src/
│   │   ├── YilnesVault.sol        # Core Logic (Premium Math)
│   │   ├── MockUSDC.sol           # USDC (6 decimals standard)
│   │   └── MockRWAProtocol.sol    # RWA Protocol Adapters
│   └── script/          # Multi-chain Deployment Scripts
├── yilnes/              # Next.js Application
│   ├── app/             # App Router Pages
│   ├── components/      # UI Components (VaultCard, InvestModal)
│   ├── hooks/           # Multi-chain Wagmi Hooks
│   ├── configs/         # Multi-chain Contract Configuration
│   └── abis/            # Contract ABIs
```

## 🚀 Quick Start

### Prerequisites
```bash
# Install dependencies
forge install
```

### Deploy Contracts
```bash
# Deploy to Mantle Sepolia
forge script script/Deploy.s.sol:DeployScript --rpc-url https://rpc.sepolia.mantle.xyz --broadcast --verify

# Deploy to Base Sepolia
forge script script/Deploy.s.sol:DeployScript --rpc-url https://sepolia.base.org --broadcast --verify
```

## 📋 Deployed Contracts

### Mantle Sepolia (Chain ID: 5003)
- **MockUSDC**: `0x4c1733B3b74F0A399F196Dc21C1C968a0baD5d40`
- **YilnesVault**: `0x857cBDd8964B639236D395BaDAC5bb3A322D0bBa`
- **MockOndo**: `0x708486290949ae9C0Ba272d8aba67d9bE5C80e47`
- **MockMaple**: `0x5Ec02ECc423375e27fbBfeB1b43A68D31703b54f`
- **MockCentrifuge**: `0x1dF7d4A25Dc700af8E714f9A0C673c76eE5341A9`
- **MockGoldfinch**: `0x1F5292C328cDaa4f6dFd432Fe2a6B48038b6467C`

### Base Sepolia (Chain ID: 84532)
- **MockUSDC**: `0xDF414037aC8D646BFB4047236Be521c58ceeAfAc`
- **YilnesVault**: `0x9465D9be3D8a09dbDed0624f99DDAB862EECAc66`
- **MockOndo**: `0x4Da7FA18e55E2E7A7b63f101AEA88854224374a3`
- **MockMaple**: `0xE1f4808f27A743C16Cd7d59e02eC5679eB2F10cd`
- **MockCentrifuge**: `0xA2ed874594283B29499c32F70Ee38608990f413a`
- **MockGoldfinch**: `0xbaBb898295BFDa0d9A7119Eb375314ef22548F4B`

All contracts are verified on their respective block explorers.

## 🔧 Key Features

### Smart Contracts
- **YilnesVault.sol**: Core vault logic with time-based premium calculations
- **MockUSDC.sol**: Standard 6-decimal USDC implementation with faucet
- **MockRWAProtocol.sol**: Simulated RWA protocols (Ondo, Maple, Centrifuge, Goldfinch)

### Multi-Chain Support
- Dynamic contract address resolution
- Chain-aware frontend components
- Cross-chain yield aggregation
- Network-specific configurations

### Token Standards
- **USDC (6 decimals)**: Industry standard stablecoin format
- **Faucet Amount**: 10,000 USDC per 24-hour period
- **Premium Model**: 2.5% annual rate, prorated by time

## 📝 Contract Interactions

### Get Test USDC
```solidity
// Claim 10,000 USDC (available every 24 hours)
MockUSDC(usdcAddress).faucet();
```

### Deposit with Insurance
```solidity
// Approve USDC
MockUSDC(usdcAddress).approve(vaultAddress, amount);

// Deposit with 90-day coverage
YilnesVault(vaultAddress).depositWithCoverage(amount, 90);
```

### Direct RWA Investment
```solidity
// Invest directly in RWA protocols
MockRWAProtocol(protocolAddress).deposit(amount, duration);
```

## 🛡️ Security Features
- **Upfront Premium Model**: Immediate safety reserve funding
- **Time-Based Coverage**: Users pay only for protection period needed
- **Multiple RWA Protocols**: Risk diversification across multiple strategies
- **Transparent Reserves**: On-chain verification of safety funds

## 🌐 Multi-Chain Architecture
- **Chain-Agnostic Frontend**: Single interface for multiple networks
- **Dynamic Contract Resolution**: Automatic address switching based on connected chain
- **Unified User Experience**: Consistent functionality across all supported networks

## 📚 Documentation
- Contract ABIs available in `/abis/` directory
- Multi-chain configuration in `/configs/contracts.ts`
- Environment variables documented in `.env.example`

## 🔗 Verification Links
- **Mantle Sepolia**: https://sepolia.mantlescan.xyz/
- **Base Sepolia**: https://sepolia.basescan.org/

---

**Built for Global Hackathon 2025** | Multi-Chain DeFi Innovation