# token-sale

## NOESIS Cyclic Token Sale

Educational web3 project for an endlessly cycling token sale on Ethereum Sepolia. NOE and mUSDC are testnet-only tokens with no monetary value.

## Status

Project scaffold initialized. Contract, bot, and frontend implementation will be added in the work stages described in [TZ_ICO_Token_Sale.md](TZ_ICO_Token_Sale.md).

## Workspaces

- `contracts/` — Hardhat contracts, tests, and deployment tooling.
- `bot/` — deterministic mock activity for 35 test wallets.
- `frontend/` — Vite and React dApp.

## Configuration

Copy `.env.example` to a local environment file only when needed. Never commit private keys, mnemonics, or API keys. Frontend variables prefixed with `VITE_` are public and are included in the browser bundle.

## Local development

Runtime and commands will be documented as each workspace is implemented. The target runtime is Node.js 22 LTS and the package manager is npm workspaces.

## Deployment and rollback

Deployment instructions will be added after the contracts and frontend are ready. The target frontend host is Vercel; rollback will use Vercel Instant Rollback.

## Educational disclaimer

This is a testnet learning project. NOE and mUSDC have no monetary value. No mainnet deployment or real payment token is in scope.
