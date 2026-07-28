# Medichain — Single-Node Besu (Demo)

A fast, hosted, real blockchain for product-owner demos. One QBFT validator,
~2s blocks, free gas, same chain ID and contract as the production 4-node setup.
Swap to the cluster later with zero app changes.

## 1. Generate genesis + the node key (local, once)

```bash
cd blockchain/besu/demo

docker run --rm -v "$PWD:/work" -w /work hyperledger/besu:24.12.0 \
  operator generate-blockchain-config \
  --config-file=/work/qbftConfigFile.json \
  --to=/work/networkFiles \
  --private-key-file-name=key
```

Then place the two files where the compose file expects them:

```bash
mkdir -p config
cp networkFiles/genesis.json config/genesis.json
cp networkFiles/keys/0x*/key config/key
```

## 2. Run the node

**On a $5 VPS (recommended for live demos):** copy `docker-compose.yml` + the
`config/` folder to the server, then:

```bash
docker compose up -d
docker compose logs -f      # look for "Imported #1" → it's producing blocks
```

**Or locally:** same `docker compose up -d`, then expose it with a tunnel so a
phone/app can reach it:

```bash
cloudflared tunnel --url http://localhost:8545
# → gives you a public https URL to use as BESU_RPC_URL
```

For a VPS, front port 8545 with nginx + Let's Encrypt (see ../README.md Phase 4)
so the app talks HTTPS.

## 3. Deploy the contract

In `blockchain/.env`:

```
PRIVATE_KEY=<your deployer key>
BESU_RPC_URL=https://your-rpc-host        # or the cloudflared https URL
BESU_CHAIN_ID=131419
```

```bash
cd blockchain
npx hardhat run scripts/deploy.js --network besu
# address is written to deployments/besu.json
```

(Gas is free — the deployer needs no balance.)

## 4. Point the app at it

In `lib/services/contract_service.dart`:

```dart
static const String _rpcUrl = 'https://your-rpc-host';
static const int _chainId = 131419;
static String _contractAddress = '<address from deployments/besu.json>';
```

Rebuild — done. Confirmations are now near-instant vs. public Amoy.

> Tip for the demo: drop `blockperiodseconds` in `qbftConfigFile.json` from `2`
> to `1` before step 1 if you want even snappier blocks.
