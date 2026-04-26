<div align="center">

# 🩺 MediChain

### *Decentralized, Patient-Owned Electronic Health Records on the Blockchain*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![Solidity](https://img.shields.io/badge/Solidity-363636?logo=solidity&logoColor=white)](https://soliditylang.org)
[![IPFS](https://img.shields.io/badge/IPFS-65C2CB?logo=ipfs&logoColor=white)](https://ipfs.tech)
[![Status](https://img.shields.io/badge/status-active%20development-brightgreen)]()

*A secure, decentralized platform that puts patients back in control of their medical history.*

[Overview](#-overview) • [Features](#-key-features) • [Architecture](#-architecture) • [Tech Stack](#-tech-stack) • [Getting Started](#-getting-started) • [Team](#-meet-the-team)

</div>

---

## 📖 Overview

**MediChain** is a blockchain-powered Electronic Health Record (EHR) system that gives patients true ownership and control over their medical data. Today, medical records are scattered across hospitals, insurance providers, and clinics — often inaccessible to the very people they belong to. MediChain fixes this by combining the immutability of blockchain, the privacy of strong encryption, and the resilience of decentralized storage to create a single, trustworthy source of truth for every patient's health journey.

Inspired by the foundational research of MIT's **MedRec** project, MediChain reimagines healthcare data exchange around three principles: **patient agency**, **data integrity**, and **interoperability**.

### 🎯 The Problem We're Solving

- **Fragmented records** across multiple hospitals and clinics make it nearly impossible for patients to maintain a complete medical history.
- **Slow, manual access** to one's own records — often delivered weeks later in incompatible formats.
- **No real ownership** — patients cannot easily share, audit, or revoke access to their data.
- **Trust gaps** between providers due to the lack of a tamper-proof, verifiable record system.

### ✨ Our Solution

MediChain creates a **patient-first ecosystem** where:
- Records are stored **off-chain in encrypted form** (IPFS + cloud) for performance and privacy.
- A **cryptographic hash** of every record is anchored on the blockchain to guarantee integrity.
- **Smart contracts** govern who can access what, when, and for how long — with the patient as the gatekeeper.
- An **immutable audit trail** logs every access event, building trust between patients and providers.

---

## 🌟 Key Features

| Category | Feature | Description |
|----------|---------|-------------|
| 🔐 **Authentication** | Role-Based Access | Separate, secure flows for patients and doctors |
| 📤 **Records** | Encrypted Upload | AES-256 encryption applied before storage |
| 🗄️ **Storage** | Hybrid Off-Chain | Encrypted files on IPFS, replicated to cloud for speed |
| ⛓️ **Blockchain** | Hash Anchoring | SHA-256 hashes stored on-chain for tamper-proof verification |
| 👤 **Patient Control** | Grant / Revoke Access | Patients approve or reject every doctor's data request |
| 🩺 **Provider Workflow** | Access Requests | Doctors submit structured requests; patients respond in-app |
| 📜 **Auditability** | Immutable Logs | Every access, grant, and revoke is recorded on-chain |
| ✅ **Integrity** | Hash Verification | Stored file hash is verified against blockchain on every retrieval |
| 🔓 **Decryption** | Secure Download | Files decrypted client-side after access is verified |

---

## 🏗️ Architecture

MediChain follows a **hybrid on-chain / off-chain architecture** — combining the trust guarantees of blockchain with the performance of traditional storage.

```
┌─────────────────┐         ┌─────────────────┐
│   Patient App   │         │   Doctor App    │
│    (Flutter)    │         │    (Flutter)    │
└────────┬────────┘         └────────┬────────┘
         │                           │
         └───────────┬───────────────┘
                     │
           ┌─────────▼─────────┐
           │  Backend (Node.js │
           │   + Express APIs) │
           └─────────┬─────────┘
                     │
       ┌─────────────┼─────────────┐
       │             │             │
┌──────▼──────┐ ┌────▼────┐ ┌──────▼──────┐
│  Encryption │ │Supabase │ │  Blockchain │
│  AES-256 +  │ │ (Meta-  │ │  (Solidity  │
│  SHA-256    │ │  data)  │ │  Contracts) │
└──────┬──────┘ └─────────┘ └─────────────┘
       │
┌──────▼──────┐
│    IPFS     │
│  (Encrypted │
│   Records)  │
└─────────────┘
```

### 🔄 How a Record Flows Through the System

1. **Upload** → Patient uploads a medical file via the Flutter app.
2. **Encrypt** → Backend encrypts the file with AES-256.
3. **Store** → Encrypted file is pushed to IPFS; CID is returned.
4. **Hash** → SHA-256 hash of the file is generated.
5. **Anchor** → Hash + metadata is stored on-chain via the smart contract.
6. **Request** → A doctor requests access; patient receives a notification.
7. **Approve** → Patient grants permission via smart contract.
8. **Retrieve** → Doctor downloads from IPFS, hash is verified against blockchain.
9. **Decrypt** → File is decrypted and displayed; access event is logged.

---

## 🛠️ Tech Stack

<div align="center">

| Layer | Technology |
|-------|------------|
| 📱 **Mobile App** | Flutter (Dart) |
| ⚙️ **Backend** | Node.js · Express · Web3.js |
| ⛓️ **Smart Contracts** | Solidity · Remix IDE |
| 🌐 **Blockchain** | Ethereum (Testnet) |
| 🔐 **Encryption** | AES-256 (data) · SHA-256 (integrity) |
| 🗂️ **Decentralized Storage** | IPFS (Pinata / Web3.Storage / Infura) |
| ☁️ **Cloud / Database** | Supabase (PostgreSQL) |
| 👛 **Wallet** | MetaMask |

</div>

---

## 📁 Project Structure

```
MediChain/
├── frontend/              # Flutter mobile application
│   ├── lib/
│   │   ├── screens/       # Login, Dashboard, Upload, Records, Profile
│   │   ├── widgets/       # Reusable UI components
│   │   ├── services/      # API clients, encryption helpers
│   │   └── models/        # Patient, Doctor, Record models
│   └── pubspec.yaml
│
├── backend/               # Node.js + Express server
│   ├── src/
│   │   ├── routes/        # Auth, records, access-control endpoints
│   │   ├── controllers/   # Business logic
│   │   ├── services/      # Encryption, IPFS, blockchain bridge
│   │   ├── middleware/    # JWT auth, role guards
│   │   └── config/        # Env, database, web3 config
│   └── package.json
│
├── contracts/             # Solidity smart contracts
│   ├── MediChain.sol      # Core record + access logic
│   ├── AccessControl.sol  # Permission management
│   └── migrations/
│
├── docs/                  # Architecture diagrams, API specs
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** (3.x or later)
- **Node.js** (v18+) and npm
- **MetaMask** browser extension or wallet app
- **Ganache** or access to an Ethereum testnet (Sepolia recommended)
- **IPFS** account (Pinata or Web3.Storage)
- **Supabase** project (for metadata + auth)

### Installation

**1. Clone the repository**
```bash
git clone https://github.com/<your-org>/medichain.git
cd medichain
```

**2. Set up the backend**
```bash
cd backend
npm install
cp .env.example .env   # fill in your keys (Supabase, IPFS, RPC URL, etc.)
npm run dev
```

**3. Deploy smart contracts**
```bash
cd ../contracts
# Open MediChain.sol in Remix, compile, and deploy to your testnet
# Copy the deployed address into backend/.env as CONTRACT_ADDRESS
```

**4. Run the Flutter app**
```bash
cd ../frontend
flutter pub get
flutter run
```

### Environment Variables

Create a `.env` file in `backend/` with the following:

```env
PORT=5000
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_anon_key
IPFS_API_KEY=your_pinata_or_web3storage_key
ETHEREUM_RPC_URL=https://sepolia.infura.io/v3/your_project_id
CONTRACT_ADDRESS=0xYourDeployedContract
PRIVATE_KEY=your_wallet_private_key
JWT_SECRET=a_strong_random_string
AES_ENCRYPTION_KEY=32_byte_key
```

---

## 🗓️ Development Roadmap

The project is being built in **four agile cycles** over six weeks:

### ✅ Cycle 1 — App + Auth (Week 1)
- Patient & doctor signup/login flows
- Role-based dashboard routing
- Basic UI scaffolding (Dashboard, Upload, Records, Profile)
- Authentication APIs and database schemas

### ✅ Cycle 2 — Data + Security Core (Weeks 2–3)
- File upload pipeline with AES-256 encryption
- IPFS / cloud storage integration
- SHA-256 hash generation
- End-to-end secure record pipeline

### ✅ Cycle 3 — Blockchain + Access Control (Weeks 4–5)
- Smart contracts for record hashing & permissions
- Wallet integration (MetaMask)
- Doctor access request → patient approval workflow
- On-chain audit logging

### 🚧 Cycle 4 — Verification + Demo (Week 6)
- Hash verification on retrieval
- Full file download + decryption flow
- UI polish, error handling, loading states
- End-to-end testing
- Final demo, architecture diagrams, presentation

---

## 👥 Meet the Team

<div align="center">

| Name | Role | Primary Responsibilities |
|------|------|--------------------------|
| 🎨 **Piyush** | Frontend Lead | Flutter UI, dashboards, upload & request flows, UX polish |
| ⚙️ **Darsh** | Backend & Blockchain Integration | Auth APIs, file APIs, backend ↔ blockchain bridge, coordination |
| 📊 **Akshita** | Data & Documentation Lead | Data models, schemas, API coordination, testing & docs |
| 🔐 **Prakash** | Security & Smart Contracts | Encryption, hashing, smart contract implementation, verification logic |

</div>

> *Built with ☕, late nights, and a shared belief that patients deserve to own their own health data.*

---

## 🤝 Contributing

This project is currently maintained by the core team listed above. If you'd like to contribute, please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

For major changes, please open an issue first to discuss what you'd like to change.

---

## 🔒 Security & Privacy Notes

- MediChain is currently a **prototype / MVP** built for academic and demonstration purposes.
- Smart contracts have **not been formally audited** — do not deploy to mainnet without a professional security review.
- All medical data is **encrypted before leaving the client**, and only encrypted blobs ever touch IPFS or cloud storage.
- Private keys must be stored securely; the project does not yet implement enterprise-grade key management.

If you discover a security vulnerability, please open a private issue or contact the team directly rather than disclosing publicly.

---

## 📚 References & Acknowledgments

This project draws inspiration and design lessons from:

- **Ekblaw, A. (2017).** *MedRec: Blockchain for Medical Data Access, Permission Management and Trend Analysis.* MIT Master's Thesis.
- The **MIT Media Lab** Viral Communications group for foundational MedRec research.
- The **Ethereum** and **IPFS** open-source communities.
- The **Flutter** team for an incredible cross-platform framework.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<div align="center">

### ⭐ If you find this project useful, please consider giving it a star!

**Made with 💙 by Team MediChain**

*Piyush · Darsh · Akshita · Prakash*

</div>
