# Yilnes: Principal Protected Yields on Mantle

> **The First "Upfront Premium" RWA Yield Aggregator.** > Institutional-grade yields ($USDY) with immediate solvency protection from Block 1.

![License](https://img.shields.io/badge/license-MIT-green)
![Network](https://img.shields.io/badge/network-Mantle%20Sepolia-blue)
![Status](https://img.shields.io/badge/status-Hackathon%20MVP-orange)

## 📖 The Problem
DeFi insurance faces a "Cold Start Paradox." Protocols traditionally build insurance funds by taxing *future* profits (e.g., 10% performance fee).
* **The Risk:** If a hack happens in Month 1, the reserve is empty. Early adopters are 100% exposed.
* **The Result:** Users are afraid to provide liquidity to new RWA strategies.

## 💡 The Yilnes Solution
We flip the model. Instead of taxing uncertain future yields, we charge a **Time-Based Premium** at the moment of deposit.
* **Instant Solvency:** Premiums flow directly into the Safety Reserve, ensuring immediate liquidity to cover losses.
* **100% Yield Retention:** Users keep all their upside because they paid for safety upfront.
* **Gamified Risk:** Users choose their term (28 to 365 days) via a slider, paying only for the coverage they need.

## 🏗️ Tech Stack
* **Network:** Mantle Sepolia Testnet
* **Contracts:** Solidity, Foundry (Forge)
* **Frontend:** Next.js 14, TypeScript, Tailwind CSS, Framer Motion
* **Web3:** Wagmi v2, Viem, ConnectKit
* **Assets:** $USDY (Ondo US Dollar Yield), $MNT

## 📂 Repository Structure
```bash
├── contracts/           # Foundry Project
│   ├── src/
│   │   ├── YilnesVault.sol    # Core Logic (Premium Math)
│   │   ├── MockUSDY.sol       # Mantle Yield Token Simulation
│   │   └── MockStrategies.sol # Ondo/Maple Adapters
│   └── script/          # Deployment Scripts
├── frontend/            # Next.js Application
│   ├── app/             # App Router Pages
│   ├── components/      # UI Components (VaultCard, InvestModal)
│   ├── hooks/           # Custom Wagmi Hooks
│   └── lib/             # Contract ABIs and Constants