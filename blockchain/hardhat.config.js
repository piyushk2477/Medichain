require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  networks: {
    // ── Local development ──────────────────────────────────────────────
    hardhat: {
      chainId: 31337,
    },

    // ── Polygon Amoy (testnet — replaced Mumbai in 2024) ──────────────
    amoy: {
      url: process.env.POLYGON_AMOY_RPC_URL || "https://rpc-amoy.polygon.technology",
      chainId: 80002,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 25000000000, // 25 Gwei — Amoy minimum required
    },

    // ── Ethereum Sepolia (testnet) ────────────────────────────────────
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "https://rpc.sepolia.org",
      chainId: 11155111,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },

    // ── Private Besu QBFT network (self-hosted, free gas) ──────────────
    besu: {
      url: process.env.BESU_RPC_URL || "http://127.0.0.1:8545",
      chainId: Number(process.env.BESU_CHAIN_ID || 131419),
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 0, // free-gas network (nodes run --min-gas-price=0)
    },

    // ── Private Ethereum node (self-hosted Geth / Clique PoA, free gas) ─
    geth: {
      url: process.env.GETH_RPC_URL || "http://200.97.171.178:8545",
      chainId: Number(process.env.GETH_CHAIN_ID || 131419),
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 0, // free-gas network (--miner.gasprice=0, baseFeePerGas 0)
    },

    // ── Polygon Mainnet ────────────────────────────────────────────────
    polygon: {
      url: process.env.POLYGON_MAINNET_RPC_URL || "https://polygon-rpc.com",
      chainId: 137,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gasPrice: "auto",
    },
  },

  // Contract verification on Polygonscan
  etherscan: {
    apiKey: {
      polygon:     process.env.POLYGONSCAN_API_KEY || "",
      polygonAmoy: process.env.POLYGONSCAN_API_KEY || "",
    },
  },

  paths: {
    sources:   "./contracts",
    tests:     "./test",
    cache:     "./cache",
    artifacts: "./artifacts",
  },
};
