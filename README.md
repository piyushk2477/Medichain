# Medichain

A decentralized medical-records app built with Flutter. Patients own their data,
control access cryptographically, and every grant/view/download is logged on-chain
as an immutable audit trail.

## Architecture

| Layer | Tech | Responsibility |
|---|---|---|
| **Mobile UI** | Flutter (Dart) | Patient & doctor screens, file upload/view |
| **Auth + metadata** | Supabase | Email login, profiles, record metadata |
| **File storage** | IPFS via [Pinata](https://app.pinata.cloud) | Encrypted file blobs, pinned by CID |
| **Access control + audit log** | Solidity (`MediAccessControl`) on Polygon | Grant/revoke access, immutable event log |
| **Local key custody** | `flutter_secure_storage` | Per-user Ethereum private key, Android Keystore-backed |

Files are AES-encrypted on-device before upload — only the patient (and doctors
they explicitly grant access to) can decrypt them.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.10
- [Node.js](https://nodejs.org/) ≥ 18 (for the Hardhat blockchain)
- An Android emulator or physical device (iOS works too, but setup is Android-first)
- Free accounts on [Supabase](https://supabase.com) and [Pinata](https://app.pinata.cloud)

## First-time setup

### 1. Clone and install Flutter dependencies

```bash
git clone https://github.com/piyushk2477/Medichain.git
cd Medichain
flutter pub get
```

### 2. Configure the Flutter app's secrets

Copy the template and fill in your own values:

```bash
cp .env.example .env
```

Edit `.env`:

```
SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
PINATA_JWT=your-pinata-jwt
PINATA_GATEWAY=your-gateway.mypinata.cloud
```

- **Supabase** → Project Settings → API → copy `Project URL` and `anon public` key.
- **Pinata** → API Keys → New Key → enable `pinFileToIPFS` scope → copy the JWT.
  Gateway subdomain is on the Gateways tab (without `https://`).

`.env` is gitignored and bundled into the app as a Flutter asset at build time.

### 3. Install blockchain dependencies

```bash
cd blockchain
npm install
```

### 4. Configure blockchain secrets (only needed for testnet/mainnet)

```bash
cp .env.example .env
```

Edit `blockchain/.env`:

```
PRIVATE_KEY=your-deployer-private-key-no-0x-prefix
POLYGON_AMOY_RPC_URL=https://polygon-amoy.g.alchemy.com/v2/YOUR_KEY
POLYGON_MAINNET_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY
POLYGONSCAN_API_KEY=your-polygonscan-api-key
```

For purely local development this can be left blank.

## Running the project

You need **three** processes running, in this order:

### Terminal 1 — local Hardhat node

```bash
cd blockchain
npx hardhat node
```

Leave this running. It exposes a local Ethereum JSON-RPC at `http://127.0.0.1:8545`,
chain ID `31337`, with 20 pre-funded test accounts.

### Terminal 2 — deploy the contract

```bash
cd blockchain
npx hardhat run scripts/deploy.js --network localhost
```

Expected output ends with:

```
MediAccessControl : 0x5FbDB2315678afecb367f032d93F642f64180aa3
Contract address saved to: deployments/localhost.json
```

If you get a different address (e.g. after restarting the Hardhat node and
deploying multiple things), update `_contractAddress` in
[lib/services/contract_service.dart](lib/services/contract_service.dart) to match.
The first contract deployed against a fresh node always lands at the address
above, so as long as you redeploy on every restart, no code change is needed.

### Terminal 3 — run the Flutter app

```bash
flutter run
```

> **Your laptop is the blockchain server.** While `npx hardhat node` is running,
> your machine exposes a JSON-RPC endpoint at port `8545`. Close the terminal
> and the chain (and all state) is gone — you'll need to redeploy on next start.
>
> **Android emulator:** the app talks to the node via `http://10.0.2.2:8545` —
> that's the emulator's loopback alias for the host's `127.0.0.1`.
>
> **Physical phone / iOS:** the emulator alias doesn't apply. Bind Hardhat to
> all interfaces, find your laptop's LAN IP, open the firewall, and edit
> [lib/services/contract_service.dart:65](lib/services/contract_service.dart#L65).
> Full walkthrough in [blockchain/README.md](blockchain/README.md#connecting-from-a-phone-on-the-same-wi-fi).

## More on the blockchain side

For details on the local node lifecycle, LAN exposure, Hardhat commands, and
deploying to Polygon Amoy/mainnet, see [blockchain/README.md](blockchain/README.md).

## Project structure

```
.
├── lib/
│   ├── main.dart              # entry point, loads .env, init Supabase
│   ├── screens/
│   │   ├── auth/              # login + signup
│   │   ├── patient/           # dashboard, upload, records, audit log
│   │   └── doctor/            # dashboard, patient records, secure viewer
│   └── services/
│       ├── supabase_service.dart   # auth + profiles
│       ├── pinata_service.dart     # IPFS upload/download (reads .env)
│       ├── wallet_service.dart     # local Ethereum key, secure storage
│       ├── contract_service.dart   # MediAccessControl read/write
│       └── sharing_service.dart    # patient→doctor sharing flow
├── blockchain/
│   ├── contracts/MediAccessControl.sol   # the on-chain access + audit contract
│   ├── scripts/deploy.js
│   ├── hardhat.config.js
│   └── deployments/           # JSON files written by deploy.js
├── .env                       # gitignored — Flutter secrets
└── blockchain/.env            # gitignored — deployer + RPC secrets
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `FileNotFoundError: .env` at app startup | Make sure `.env` exists at the project root and is listed under `flutter: assets:` in [pubspec.yaml](pubspec.yaml). Run `flutter clean && flutter pub get`. |
| `SocketException: Connection refused` from Flutter | Hardhat node isn't running, or the emulator can't reach `10.0.2.2:8545`. Check Terminal 1. |
| Contract calls revert with "no contract at address" | You restarted Hardhat (which wipes state) without redeploying. Re-run the deploy script. |
| Pinata uploads return HTTP 401 | JWT in `.env` is wrong or has been revoked. Generate a new key in the Pinata dashboard. |

## Security notes

- **`.env` is shipped inside the APK as a Flutter asset.** Anyone can extract it
  from a built `.apk`. The Supabase **anon** key is fine (it's designed to be
  public, gated by Row-Level Security policies). The Pinata JWT is **not** —
  for production, proxy uploads through a Supabase Edge Function so the secret
  stays server-side.
- The deployer `PRIVATE_KEY` in `blockchain/.env` should never be funded on
  mainnet — use a dedicated deployer wallet you can rotate.
- Per-user wallets are generated on signup and stored in
  `flutter_secure_storage` (Android Keystore-backed encrypted shared prefs).
  They never leave the device.
