/**
 * Medichain — Private Ethereum (Geth / Clique PoA) generator
 * ──────────────────────────────────────────────────────────
 * Run ONCE, locally. Produces everything you need to boot a single-node
 * private Ethereum chain on your VPS, with a BRAND-NEW "host" wallet that is
 * both the block signer (Clique) and the contract deployer.
 *
 *   cd blockchain
 *   node geth/generate.js                 # makes a brand-new random wallet, OR
 *   node geth/generate.js 0xYOUR_METAMASK_PRIVATE_KEY   # uses YOUR MetaMask wallet
 *
 * To use your MetaMask account as the host: in MetaMask open the account →
 * three dots → "Account details" → "Show private key", copy it, and pass it as
 * the argument above (or set HOST_PRIVATE_KEY in the environment).
 * ⚠ Use a FRESH MetaMask account with no real funds — this key goes on the VPS.
 *
 * Outputs (all inside blockchain/geth/out/ — gitignored, keep secret):
 *   wallet.json     — { address, privateKey }  (your new host/deployer wallet)
 *   signer-key.txt  — raw private key (no 0x)   (import into geth on the VPS)
 *   password.txt    — random keystore password  (used to unlock the signer)
 *   genesis.json    — the chain genesis (Clique PoA, this wallet as sole signer)
 *
 * CHAIN_ID: change below if you want a different chain id. Keep it unique-ish
 * so it never collides with a public network your wallet might also use.
 */
const { ethers } = require("ethers");
const fs   = require("fs");
const path = require("path");
const crypto = require("crypto");

// ── Config you can tweak ────────────────────────────────────────────────
const CHAIN_ID   = 131419;                 // your private chain id
const BLOCK_TIME = 2;                       // seconds per block (Clique period)
const PREFUND    = "1000000000000000000000000000"; // 1e9 ETH to the deployer

// ── 1. Host wallet (signer + deployer) ──────────────────────────────────
// Use YOUR MetaMask key if given (arg or HOST_PRIVATE_KEY), else make a new one.
const givenKey = process.argv[2] || process.env.HOST_PRIVATE_KEY;
const wallet = givenKey
  ? new ethers.Wallet(givenKey.startsWith("0x") ? givenKey : "0x" + givenKey)
  : ethers.Wallet.createRandom();
console.log(givenKey ? "\nUsing your provided (MetaMask) wallet." : "\nGenerated a new random wallet.");
const address = wallet.address;                    // 0x-checksummed
const pkNo0x  = wallet.privateKey.replace(/^0x/, "");
const addrNo0x = address.slice(2).toLowerCase();

// ── 2. Clique extraData = 32-byte vanity + signer(s) + 65-byte seal ──────
const vanity = "0".repeat(64);   // 32 bytes
const seal   = "0".repeat(130);  // 65 bytes
const extraData = "0x" + vanity + addrNo0x + seal;

// ── 3. Genesis (all forks at block 0, London active, base fee 0 = free) ──
const genesis = {
  config: {
    chainId: CHAIN_ID,
    homesteadBlock: 0,
    eip150Block: 0,
    eip155Block: 0,
    eip158Block: 0,
    byzantiumBlock: 0,
    constantinopleBlock: 0,
    petersburgBlock: 0,
    istanbulBlock: 0,
    berlinBlock: 0,
    londonBlock: 0,
    clique: { period: BLOCK_TIME, epoch: 30000 },
  },
  nonce: "0x0",
  timestamp: "0x0",
  extraData,
  gasLimit: "0x1fffffffffffff",
  difficulty: "0x1",
  mixHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  coinbase: "0x0000000000000000000000000000000000000000",
  baseFeePerGas: "0x0",
  alloc: {
    [addrNo0x]: { balance: PREFUND },
  },
};

// ── 4. Write outputs ────────────────────────────────────────────────────
const outDir = path.join(__dirname, "out");
fs.mkdirSync(outDir, { recursive: true });

const password = crypto.randomBytes(18).toString("base64").replace(/[/+=]/g, "");

fs.writeFileSync(path.join(outDir, "genesis.json"), JSON.stringify(genesis, null, 2));
fs.writeFileSync(path.join(outDir, "wallet.json"),
  JSON.stringify({ address, privateKey: wallet.privateKey, chainId: CHAIN_ID }, null, 2));
fs.writeFileSync(path.join(outDir, "signer-key.txt"), pkNo0x + "\n");
fs.writeFileSync(path.join(outDir, "password.txt"), password + "\n");

console.log("\n✅ Generated private Ethereum (Geth/Clique) config\n");
console.log("  Chain ID     :", CHAIN_ID);
console.log("  Host wallet  :", address);
console.log("  Output dir   : blockchain/geth/out/");
console.log("\n  Files: genesis.json, wallet.json (SECRET), signer-key.txt (SECRET), password.txt (SECRET)");
console.log("\n  ⚠  Never commit blockchain/geth/out/ — it holds your private key.\n");
