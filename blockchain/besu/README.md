# Medichain — Private Besu QBFT Network (Production)

A self-hosted, permissioned, **4-validator** Hyperledger Besu network using **QBFT**
consensus. No gas fees, no data leaving your infrastructure. This replaces the
public Amoy testnet for production.

- **Consensus:** QBFT (Byzantine fault tolerant — 4 validators tolerate 1 failing node)
- **Gas:** free (`--min-gas-price=0`, `zeroBaseFee`)
- **Chain ID:** `131419` (change in `qbftConfigFile.json` if you like)
- **What runs on-chain:** only `MediAccessControl` (access grants + audit log).
  PHI never goes on-chain — files stay on IPFS, metadata in Supabase.

> ⚠️ **Do not commit secrets.** Node keys (`config/key`), the deployer private key,
> and `.env` files must never be committed. See `.gitignore`.

---

## Cost (recap)

| Item | Spec | Provider | Monthly |
|---|---|---|---|
| 4 × validator VPS | 2 vCPU / 4–8 GB / 40 GB SSD | Hetzner CX22 (~€4.5) | ~€18 / ~$20 |
| Gateway (nginx+TLS) | can reuse node-1, or +1 small VPS | — | $0–6 |
| Domain + TLS (Let's Encrypt) | — | — | ~$1 (domain only) |
| **Total** | | | **~$20–30 / mo** |

Scale RAM to 8 GB per node if the chain grows; CPU/disk needs stay low for this workload.

---

## Phase 1 — Generate genesis + validator keys (do this once, locally)

You need the Besu CLI. Easiest is via Docker (no install):

```bash
cd blockchain/besu

# 1. Put your DEPLOYER address into qbftConfigFile.json (the "alloc" key),
#    so the account that deploys the contract is pre-funded. The address is
#    derived from the PRIVATE_KEY you'll put in blockchain/.env.

# 2. Generate genesis.json + 4 node key pairs:
docker run --rm -v "$PWD:/work" -w /work hyperledger/besu:24.12.0 \
  operator generate-blockchain-config \
  --config-file=/work/qbftConfigFile.json \
  --to=/work/networkFiles \
  --private-key-file-name=key
```

This produces:

```
networkFiles/
├── genesis.json                 ← identical on all 4 nodes
└── keys/
    ├── 0xabc.../ key, key.pub   ← node 1 (key = private, key.pub = enode pubkey)
    ├── 0xdef.../ key, key.pub   ← node 2
    ├── 0x123.../ key, key.pub   ← node 3
    └── 0x456.../ key, key.pub   ← node 4
```

The 4 generated addresses are your **initial validator set** (already baked into
`genesis.json`'s QBFT extraData).

---

## Phase 2 — Provision 4 VPS

Create 4 small servers (Hetzner CX22 / DigitalOcean / any). On each:

```bash
# Install Docker + compose plugin
curl -fsSL https://get.docker.com | sh

# Open ONLY what's needed:
#   30303/tcp+udp  → P2P, open to the OTHER 3 node IPs only
#   8545/tcp       → RPC, DO NOT expose publicly (firewall to localhost/nginx)
#   22/tcp         → SSH
ufw allow 22/tcp
ufw allow 30303
ufw enable
```

Record each server's **public IP** — you'll need all four.

---

## Phase 3 — Run a node on each VPS

On **each** VPS, create a working dir and copy in that node's files:

```
~/medichain-besu/
├── docker-compose.yml          ← from this folder
├── .env                        ← from .env.example, filled for THIS node
└── config/
    ├── genesis.json            ← the SAME genesis.json for all nodes
    └── key                     ← THIS node's private key (networkFiles/keys/0x.../key)
```

Fill `.env` for that node:
- `P2P_HOST` = this server's public IP
- `BOOTNODES` = enode URLs of the **other three** nodes:
  `enode://<key.pub-without-0x>@<that-node-public-ip>:30303`

Then start it:

```bash
cd ~/medichain-besu
docker compose up -d
docker compose logs -f          # watch for "Imported #1 block" → consensus working
```

Once ≥3 of the 4 nodes are up and peered, blocks start being produced every 2s.
Check peer count on any node:

```bash
curl -s -X POST localhost:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
```

---

## Phase 4 — RPC gateway (nginx + TLS)

The Flutter app must reach RPC over **HTTPS**, and you should never expose port
8545 raw to the internet. Put nginx + Let's Encrypt in front of **one** node
(e.g. node-1, or a dedicated tiny gateway VPS pointing at the node's private IP).

```nginx
# /etc/nginx/sites-available/medichain-rpc
server {
    listen 443 ssl;
    server_name rpc.medichain.example.com;

    ssl_certificate     /etc/letsencrypt/live/rpc.medichain.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/rpc.medichain.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8545;   # or http://<node1-private-ip>:8545
        proxy_set_header Host $host;
        # Optional hardening: allow only eth_* read + tx submit, rate-limit, etc.
    }
}
```

```bash
certbot --nginx -d rpc.medichain.example.com
```

For HA later, point nginx `upstream` at 2–3 nodes' RPC ports.

---

## Phase 5 — Deploy the contract

Locally, in `blockchain/`, set these in `.env`:

```
PRIVATE_KEY=<deployer key — its address must match the alloc in qbftConfigFile.json>
BESU_RPC_URL=https://rpc.medichain.example.com
BESU_CHAIN_ID=131419
```

Then:

```bash
cd blockchain
npx hardhat run scripts/deploy.js --network besu
```

The deployed address is written to `deployments/besu.json`.

---

## Phase 6 — Point the app at Besu

Update the three constants in `lib/services/contract_service.dart`:

```dart
static const String _rpcUrl = 'https://rpc.medichain.example.com';
static const int _chainId = 131419;
static String _contractAddress = '<address from deployments/besu.json>';
```

Rebuild the app. Everything else (grant/revoke/log/query) works unchanged — the
contract ABI and Flutter logic are identical to the Amoy/local setup.

---

## Operations notes

- **Backups:** the `besu-data` volume holds the chain; snapshot the VPS or back up
  the volume. With 4 nodes the chain survives one node loss, but keep an off-box
  backup of `networkFiles/` (genesis + keys) — losing all keys is unrecoverable.
- **Adding/removing validators:** done at runtime via QBFT RPC
  (`qbft_proposeValidatorVote`), not by editing genesis. Needs a majority vote.
- **Monitoring:** scrape Besu metrics (`--metrics-enabled`) into Prometheus/Grafana.
- **Compliance:** on-chain data is immutable — never write PHI or anything subject
  to right-to-erasure. Keep the current design (only access control + audit events).
