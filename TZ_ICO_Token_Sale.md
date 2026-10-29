# Technical Specification — NOESIS Cyclic Token Sale dApp

> Educational web3 pet project. **Ethereum Sepolia testnet only.** NOE and mUSDC have no monetary value.

---

## 0. Rules for the agent

| # | Rule |
|---|------|
| 1 | The project root is the folder you were launched in (`01_AGENT/`). All code, configs and docs live there. Never touch anything outside it. |
| 2 | Follow `CLAUDE.md`: show a plan → wait for an explicit "yes" → act. One approval = one action. |
| 3 | **Communicate with the user in English** (this overrides the language line in `CLAUDE.md`). Code, comments and commits are in English. |
| 4 | Sepolia (11155111) and local Hardhat (31337) only. Any other chainId must abort every script. |
| 5 | The user enters all private keys, mnemonics and API keys themselves. Never ask for them, print them, log them or commit them. |
| 6 | Libraries listed in §5 are approved by this spec. Any other dependency must be proposed first. Still ask before running installs. |
| 7 | Work in small steps; the project must build and pass tests after each one. One step = one commit. |
| 8 | After each stage, report the result and add 2–3 lines on **which web3 concept was applied** (the user is learning). |

---

## 1. Goal and flows

Build a website for a **never-ending token sale**. Rounds repeat forever, so every phase can be shown in a presentation **without redeploying the contracts**. A mock bot keeps each round busy with realistic activity.

**Participant flow:** connect wallet → get test mUSDC → approve (or permit) → commit mUSDC during Participation → during Claim, claim NOE + any excess-USDC refund.

**Presenter flow:** open the site at any time and show: the live round (progress bar growing, leaderboard changing), finished rounds (oversubscribed / undersubscribed, rollover), and the claim phase — all on the same contracts.

---

## 2. Prerequisites (done by the user)

- MetaMask with a **dedicated test wallet** (owner/deployer). Never a wallet that holds real funds.
- Sepolia ETH from a faucet: for the owner (deploy) and the bot funder (gas for 35 bots).
- Alchemy (or Infura) account → Sepolia RPC URL. Use a second key, restricted to the Vercel domain, for the frontend.
- Etherscan API key (contract verification).
- Reown (WalletConnect) Cloud projectId.
- GitHub repository (+ Secrets and Variables for the bot workflow), Vercel account.

---

## 3. Token concept — NOESIS (NOE)

| Item | Value |
|------|-------|
| Name / ticker | **NOESIS / NOE** (Greek *noesis* — "intellect, thinking") |
| Tagline | *Collective intelligence, on-chain.* |
| Story | Utility token of the fictional **Noesis Network**, a network of AI agents. NOE pays for agent compute and gives holders a vote on which models run in the network. |
| Disclaimer | Shown in the hero, the footer and the FAQ: "Educational testnet project. NOE has no monetary value." |
| Visual metaphor | **Neural constellation**: neuron nodes linked by thin lines, with signal pulses travelling along the edges. Each round is a new "synapse firing". |

**Design tokens (dark theme only):**

| Token | Value |
|-------|-------|
| Background | `#05060A` |
| Glass surface | `rgba(255,255,255,0.04)` + `backdrop-blur`, border `rgba(255,255,255,0.08)` |
| Primary gradient | violet `#8B5CF6` → cyan `#22D3EE` |
| Accent | magenta `#E879F9` |
| Status | success `#34D399`, warning `#FBBF24`, error `#F87171` |
| Text | `#E5E7EB`, muted `#9CA3AF` |
| Fonts (self-hosted via `@fontsource`) | Space Grotesk (headings), Inter (body), JetBrains Mono (numbers, addresses) |

**Graphics (the agent draws all of it in SVG/CSS; no stock images, no third-party brands):**
- SVG logo: 7 connected nodes forming a stylised "N", with a gradient stroke.
- Favicon and a 1200×630 OG image derived from the logo.
- Animated neuron-particle background in the hero.
- Respect `prefers-reduced-motion`: switch animations off.

---

## 4. Architecture

```
 User wallet (MetaMask / WalletConnect)
        │ signs tx
        ▼
 React SPA on Vercel (static) ──── read via RPC (Alchemy) ────┐
 wagmi · viem · RainbowKit                                    ▼
                                                    Ethereum Sepolia
                                                    ├─ CyclicSale   rounds · commit · claim · rollover
                                                    ├─ NoesisToken  ERC-20 NOE, minted on claim
                                                    └─ MockUSDC     ERC-20 mUSDC, faucet, permit
                                                              ▲
 GitHub Actions (hourly cron) ── mock:tick ── 35 bot wallets ─┘
```

- **No backend, no database, no indexer.** The contracts are the source of truth. The leaderboard and round history come from on-chain view functions, batched through Multicall3.
- **Chain time is the source of truth.** Phases and countdowns are computed from the latest block timestamp, corrected by the time elapsed since that block was fetched. Never use the browser clock (local time-travel would break it).
- npm workspaces monorepo:

```
/ (project root = 01_AGENT)
├── CLAUDE.md · TZ_ICO_Token_Sale.md · README.md
├── .gitignore · .env.example · package.json (workspaces) · docker-compose.yml
├── .github/workflows/  ci.yml (lint+test+build) · mock-bot.yml (hourly)
├── contracts/          Hardhat 3
│   ├── contracts/      NoesisToken.sol · MockUSDC.sol · CyclicSale.sol
│   ├── test/
│   ├── ignition/       modules/ · parameters/ · deployments/
│   ├── scripts/        config-check.ts · export-abi.ts · demo-local.ts
│   └── sale.config.ts  ← configurator
├── bot/src/            tick.ts · wallets.ts · strategy.ts · funder.ts
└── frontend/           Vite + React
    ├── public/         logo.svg · favicon.svg · og.png
    └── src/            abi/ (generated) · components/{ui,magicui,sale,leaderboard,…}
                        hooks/ · lib/ (chain, format, zod schemas) · content/ (copy, FAQ, roadmap)
```

- ABIs are generated into `frontend/src/abi/` by `export-abi`. Contract addresses reach the frontend through `VITE_*` env vars.

---

## 5. Tech stack

| Layer | Choice |
|-------|--------|
| Chain | Ethereum Sepolia (11155111); local Hardhat node (31337, interval mining every 2 s) |
| Contracts | Solidity ^0.8.24, OpenZeppelin Contracts v5 |
| Contract tooling | Hardhat 3 + viem + TypeScript, Hardhat Ignition (deploy), Hardhat keystore (secrets), hardhat-verify, solidity-coverage |
| Bot | TypeScript + viem (separate `bot` workspace), run with `tsx` |
| Frontend | Vite + React + TypeScript |
| Web3 client | wagmi + viem + RainbowKit + TanStack Query |
| UI | Tailwind CSS v4, shadcn/ui, Magic UI, Motion, lucide-react, sonner, react-hook-form + zod (see §10) |
| RPC / explorer | Alchemy · Etherscan (Sepolia) |
| Hosting / CI | Vercel (Hobby) · GitHub Actions |
| Runtime | Node 22 LTS. Use the latest stable, mutually compatible versions, pinned by `package-lock.json`. |

Why Hardhat and not Foundry: Foundry installs via `curl | bash`, which this environment blocks. Hardhat installs via npm and uses the same language (TypeScript) as the frontend.

---

## 6. Sale cycle and allocation rules

```
genesis
  │◀──────── Round 0 ────────▶│◀──────── Round 1 ────────▶│
  │  Participation 10 h │Claim│  Participation 10 h │Claim│  …forever
  │  commit mUSDC       │ 3 h │                     │ 3 h │
                         └── unsold + unclaimed NOE ──▶ Round 1 pool
```

| Rule | Formula / behaviour |
|------|---------------------|
| Cycle | `cycle = P + C` (P = participation 10 h, C = claim 3 h). No keeper: everything follows from time. |
| Current round | `r = floor((now − genesis) / cycle)`; before `genesis` → **Upcoming** |
| Phase | `offset = (now − genesis) mod cycle`; `offset < P` → **Participation**, else **Claim** |
| Round dates | `participationStart(r) = genesis + r·cycle`, `participationEnd(r) = claimStart(r) = +P`, `claimEnd(r) = +P+C` = start of round r+1 |
| Pool | `pool(0) = basePool`; `pool(r) = basePool + rollover(r−1)` |
| Rollover | `rollover(r) = pool(r) − claimedTokens(r)`. This covers both **unsold** NOE (undersubscribed round) and **unclaimed** NOE (claim window missed). An empty round rolls over its whole pool. |
| Target raise | `target(r) = pool(r) × price` |
| Undersubscribed (`total ≤ target`) | `tokens_i = committed_i / price`, `refund_i = 0` |
| Oversubscribed (`total > target`) | Pro-rata: `tokens_i = floor(committed_i × pool / total)`, `refund_i = floor(committed_i × (total − target) / total)` |
| Rounding | Compute tokens and refunds independently, rounding down, so that `Σtokens ≤ pool` and `Σrefund ≤ total − target`. Dust stays in the contract. |
| Claim window | Claim during `[claimStart, claimEnd)` → mint NOE + refund. After `claimEnd` → **refund only**; the NOE is forfeited to the next pool. |
| Refunds | **Never expire.** They are user funds. |
| Proceeds | `raised(r) = min(total, target)` can go to the treasury once `participationEnd(r)` has passed. |
| Limits | Per wallet per round: `minCommit ≤ Σcommits ≤ maxCommitPerWallet`. No overall cap: oversubscription is allowed. |
| No | soft cap, hard cap, vesting, multi-tier pricing |

---

## 7. Smart contracts

### 7.1 `NoesisToken` — ERC-20 + AccessControl
- name `Noesis`, symbol `NOE`, 18 decimals (from config).
- `mint(to, amount)` restricted to `MINTER_ROLE` (= `CyclicSale`). No premint. Total supply = all NOE claimed so far.

### 7.2 `MockUSDC` — ERC-20 + ERC20Permit
- name `Mock USDC`, symbol `mUSDC`, **6 decimals**. Named this way on purpose so it does not impersonate real USDC.
- `faucetMint(to, amount)`: anyone can call it, at most 10,000 mUSDC per call.

### 7.3 `CyclicSale`
**Immutable attributes** (set from config at deploy time, never changed afterwards): `token`, `paymentToken`, `price` (mUSDC per 1 NOE), `basePool`, **`genesisTime` (start date of round 0)**, **`participationDuration`**, **`claimDuration`**, `minCommit`, `maxCommitPerWallet`, `treasury`. Every round exposes **its own start and end dates** for both phases through `roundInfo(r)`.

| Function | Caller | Conditions / effect |
|----------|--------|---------------------|
| `commit(amount)` | anyone | Participation phase, not paused, limits respected; `transferFrom` mUSDC; registers a participant on their first commit in the round |
| `commitWithPermit(amount, deadline, v, r, s)` | anyone | Same as `commit`, using EIP-2612 permit. Wrap `permit` in try/catch (front-run safe). |
| `claim(round)` | participant | After `participationEnd(round)`. Inside the claim window → mint NOE + refund. After it → refund only. At most one claim per address per round. |
| `withdrawProceeds(round)` | owner | After `participationEnd(round)`; sends `raised − alreadyWithdrawn` to the treasury |
| `pause()` / `unpause()` | owner | Blocks `commit*` only. Claims and refunds always work. |
| `currentRound()`, `phase()` | view | Time-derived |
| `roundInfo(r)` | view | All 4 phase dates, pool, rolloverIn, target, totalCommitted, participantsCount, claimedTokens, subscription (bps), raised, withdrawn |
| `positionOf(r, addr)` | view | committed, tokens, refund, claimed flag, status |
| `getParticipants(r, offset, limit)` | view | Paginated `(address, committed, claimed)` for the leaderboard |
| `saleConfig()` | view | All immutables in one call |

- **Settlement is lazy and O(1)**, however many rounds were skipped. For example, k empty rounds add `k × basePool` to the carry. Views compute this virtual state without writing to storage.
- Events: `Committed`, `Claimed(round, user, tokens, refund)`, `RoundSettled(round, pool, rollover)`, `ProceedsWithdrawn`.
- Security: Ownable2Step, ReentrancyGuard, SafeERC20, checks-effects-interactions, custom errors, no ETH accepted.

**Tests (coverage ≥ 90%):**
- Phase and round math across many cycles, including the exact boundaries.
- Undersubscribed and oversubscribed rounds; rounding and dust invariants.
- Rollover, including skipped empty rounds.
- Claim inside the window vs refund-only after it.
- The permit path; per-wallet limits; pause; withdraw limits; reentrancy.

---

## 8. Configurator and contract deployment

**Configurator = one config file plus CLI commands.** There is no web UI for it. Parameters are frozen once deployed.

```ts
// contracts/sale.config.ts
const base = {
  token: { name: "Noesis", symbol: "NOE" },
  priceUsdc: "0.01",              // 1 NOE = 0.01 mUSDC
  basePoolNoe: "100000",          // → target 1,000 mUSDC per round (+ rollover)
  minCommitUsdc: "1",
  maxCommitPerWalletUsdc: "200",  // per round
  paymentToken: "deploy-mock",    // or an existing ERC-20 address with 6 decimals
  treasury: "0xYourTestWallet",
};
export default {
  localhost: { ...base, genesis: "now+2m", participation: "10m", claim: "3m" },
  sepolia:   { ...base, genesis: "2026-11-03T12:00:00+03:00", participation: "10h", claim: "3h" },
} satisfies Record<string, SaleConfig>;
```

Dates are ISO 8601 with a timezone and are converted to unix seconds. Amounts are decimal strings, converted to base units.

**Validation (`config:check` must fail with a clear message):**

| Check | Rule |
|-------|------|
| Network | chainId ∈ {31337, 11155111}, otherwise abort |
| Genesis | Sepolia: ≥ now + 10 min. Localhost: ≥ now + 1 min. |
| Durations | `participation > 0`, `claim > 0`; Sepolia uses the agreed 10 h / 3 h |
| Economics | `price > 0`, `basePool > 0`, `0 < minCommit ≤ maxCommitPerWallet` |
| Addresses | `treasury ≠ 0x0`; an existing `paymentToken` must report `decimals() == 6` |

**Commands:**

| Command | Does |
|---------|------|
| `npm run config:check -- --network <n>` | Validates the config, prints a summary table (incl. the first 3 rounds' dates in local time and UTC) and writes the Ignition parameters file |
| `npm run deploy:local` | Hardhat node + full deploy + exports ABIs and `frontend/.env.local` |
| `npm run demo:local` | Time-travels through 3 full cycles with the bot (over/undersubscribed, claims, expiries) for a fast demo |
| `npm run deploy:sepolia` | Runs the procedure below |
| `npm run verify:sepolia` | Verifies all 3 contracts on Etherscan |

**Sepolia deploy procedure:**
1. Tests green → `config:check` → deployer balance check.
2. Print a summary and **wait for the user's confirmation**.
3. Ignition deploy: `MockUSDC` → `NoesisToken` → `CyclicSale` → grant `MINTER_ROLE` to the sale → the deployer renounces the token admin role (nobody else can ever mint).
4. Verify on Etherscan → smoke-read `saleConfig()` and `roundInfo(0)` and compare them with the config.
5. Print the `VITE_*` values for Vercel, write `frontend/.env.local`, put the addresses and Etherscan links in the README, and commit `ignition/deployments/chain-11155111/`.

---

## 9. Mock bot (presentation activity)

- **Wallets:** derived from `MOCK_MNEMONIC`. Index 0 = funder; indexes 1–35 = **35 bot wallets**. Test-only mnemonic: never reuse it.
- **`npm run mock:tick`** reads the current round and phase and acts. It is **idempotent**: re-running it never double-commits or double-claims.

| Phase | Behaviour |
|-------|-----------|
| Participation | Each bot gets a seeded random **buy slot** (hours 0–9 of the round, scaled for local durations), so the progress bar and leaderboard grow live through the round. In its slot, the bot faucet-mints mUSDC if needed and commits a **different amount**. Amounts follow a skewed (whale/minnow) distribution within `[min, max]` and are scaled by a seeded per-round **demand factor** of 0.5×–3× target, so both over- and undersubscribed rounds happen. A `--demand <x>` CLI override is available. |
| Claim | About 75% of bots (seeded) claim. The rest skip, so rollover is visible in the next pool. |
| Next round | The bots that skipped claim refund-only, which demonstrates the expired-claim state. |

- **Seeds** = `keccak256(round, botIndex)`, so runs are deterministic and reproducible.
- **Gas:** the funder tops up any bot below 0.002 ETH to 0.005 ETH. The bot logs a summary per run (round, phase, actions, committed, subscription %, funder balance, estimated cycles left). It warns and exits cleanly if the funder is low.
- **GitHub Actions** (`.github/workflows/mock-bot.yml`):
  - Triggers: `schedule: cron "7 * * * *"` (hourly) + `workflow_dispatch` (with an optional `demand` input). `concurrency: mock-bot` prevents overlapping runs.
  - Secrets: `MOCK_MNEMONIC`, `SEPOLIA_RPC_URL`. Variables: contract addresses. **The owner key never goes to CI.**
  - Note in the README: GitHub disables scheduled workflows after 60 days without repo activity, and cron runs can be delayed.

---

## 10. Frontend

### 10.1 UI stack (style: crypto × AI, dark, glass, neon gradients)

| Library | Used for |
|---------|----------|
| Tailwind CSS v4 | Styling with the §3 design tokens as CSS variables |
| **shadcn/ui** (Radix-based; code copied into `components/ui`) | Card, Button, Input, Form, Progress, Badge, Tabs, Select, Table, Tooltip, Accordion, Skeleton |
| **Magic UI** (copied into `components/magicui`) | Particles (hero background), BorderBeam (sale card), NumberTicker (live amounts), ShimmerButton (main CTA), AnimatedGradientText (hero title) |
| Motion | Section reveal and state transitions |
| RainbowKit | Wallet modal with a custom dark theme (accent `#8B5CF6`, radius to match the cards) |
| react-hook-form + zod | Amount form and validation |
| sonner | Transaction toasts |
| lucide-react | Icons |
| Plain SVG | Timeline, tokenomics flow (no chart library) |

### 10.2 Page (single page, anchor navigation)

| # | Section | Elements |
|---|---------|----------|
| 1 | Header (sticky, glass) | Logo, anchors (Sale · Leaderboard · History · FAQ), network badge, RainbowKit Connect |
| 2 | Network banner | Shown on the wrong network: "Switch to Sepolia" button |
| 3 | Hero | AnimatedGradientText "NOESIS", tagline, CTAs "Join Round #N" / "How it works", Particles background, "Testnet" badge |
| 4 | **Cycle timeline** | Round #N badge; bar split Participation 10 h \| Claim 3 h with a "now" marker; **start and end date-times** of each phase in local time (UTC in a tooltip); countdown `dd:hh:mm:ss` to the end of the phase; start time of the next round |
| 5 | **Participation card** (BorderBeam) | Pool (base + rollover highlighted), price, target, participants count, **progress bar**, **amount input**, preview, "Get test USDC" button, Approve → Commit stepper (permit when supported), ShimmerButton |
| 6 | **Claim card** (in the Claim phase) | Countdown "Claim closes in …", your NOE + refund, Claim button, "Unclaimed NOE heading to Round N+1: X". After the window: "NOE rolled into Round N+1 · refund still available" + Claim refund. |
| 7 | My position | Rounds you joined: committed, NOE, refund, status (Claimable / Claimed / Expired / Refund available), "Add NOE to wallet" |
| 8 | **Leaderboard** (per round) | Round dropdown (current by default); columns: rank, address (short, copy, Etherscan link), committed mUSDC, NOE allocation, share %, refund, claim status. Gradient badges for the top 3. The connected wallet's row is highlighted and pinned. Live refresh on new events. |
| 9 | Round history | Last 10 rounds: dates, pool, rollover-in, committed, subscription %, claimed, rolled over; over/under badge |
| 10 | How it works | 4 steps: Commit → Allocate → Claim → Rollover |
| 11 | Tokenomics | SVG flow: base emission → round pool → claimed (supply) / unclaimed → next pool. Price; supply = minted on claim. |
| 12 | Roadmap | Fictional phases: Spark (testnet sale) → Signal (agent compute credits) → Swarm (multi-agent marketplace) → Consensus (model governance) |
| 13 | FAQ (Accordion) | Oversubscription; missing the claim window (NOE forfeited, refund kept); getting Sepolia ETH and mUSDC; "Activity is simulated by a bot of 35 test wallets"; testnet disclaimer |
| 14 | Admin (owner only) | Read-only params, pause/unpause, withdraw proceeds per round, treasury balance |
| 15 | Footer | Contract addresses (copy + Etherscan), GitHub link, disclaimer |

### 10.3 Progress bar
- Value = `totalCommitted / target`. Uses `role="progressbar"` with ARIA values.
- **≤ 100%:** violet→cyan gradient fill. Label "62% of target · full allocation".
- **> 100%:** full bar with a shimmer and a magenta glow. Marker at 100% labelled "Target 1,000 mUSDC". Label "245% subscribed · pro-rata active".
- Below the bar: committed (NumberTicker) / target · participants · pool.

### 10.4 Amount input and validation (zod + live on-chain constraints)

| Check | Error / button label |
|-------|----------------------|
| Wallet connected | "Connect wallet" |
| Chain = Sepolia | "Switch to Sepolia" |
| Phase = Participation, not paused | "Round in claim phase" / "Sale paused" / "Starts in …" |
| Digits + one separator only (`,` → `.`), ≤ 6 decimals, no sign or exponent | "Enter a valid amount" |
| > 0 and ≥ `minCommit` | "Min 1 USDC" |
| ≤ `maxCommitPerWallet − alreadyCommittedThisRound` | "Exceeds wallet limit (X left)" |
| ≤ mUSDC balance | "Insufficient USDC" + "Get test USDC" link |
| ETH balance > estimated gas | "Not enough Sepolia ETH for gas" |
| Allowance < amount (no permit) | "Approve USDC" (approve the exact amount, never unlimited) |
| All OK | "Commit" |

- The input has an mUSDC suffix, shows the wallet balance and has MIN / 25% / 50% / MAX chips (MAX = the smaller of balance and remaining wallet limit).
- Live preview: "If the round closed now: ≈ N NOE · ≈ X mUSDC refund".
- Errors appear inline under the field. The primary button stays disabled and shows the reason as its label.
- `simulateContract` runs before every write. Contract custom errors are decoded into human-readable messages.

### 10.5 UX states
- Skeletons while loading. Read-only mode without a wallet. RPC error with a Retry button.
- Toasts: signing → pending (Etherscan link) → success / error ("Rejected in wallet" is not shown as an error).
- Refetch after each confirmed tx and on new blocks.
- Responsive from 375 px. Keyboard accessible.

---

## 11. Environments and secrets

| Variable | Used by | Secret | Where it lives |
|----------|---------|--------|----------------|
| `SEPOLIA_PRIVATE_KEY` | deploy, admin scripts | **yes** | Hardhat keystore only, **never in CI** |
| `MOCK_MNEMONIC` | bot | **yes** (test-only) | Hardhat keystore / GitHub Secret |
| `SEPOLIA_RPC_URL` | contracts, bot | **yes** | Hardhat keystore / GitHub Secret |
| `ETHERSCAN_API_KEY` | verify | **yes** | Hardhat keystore |
| `VITE_RPC_URL` | frontend | public (in bundle) | `.env.local` / Vercel. Use a separate, domain-restricted key. |
| `VITE_CHAIN_ID`, `VITE_SALE_ADDRESS`, `VITE_TOKEN_ADDRESS`, `VITE_USDC_ADDRESS` | frontend | no | `.env.local` / Vercel |
| `VITE_WALLETCONNECT_PROJECT_ID` | frontend | no | `.env.local` / Vercel |

- Hardhat config reads secrets via `configVariable()`: the keystore locally, env vars in CI. The user runs `npx hardhat keystore set …` personally.
- Everything prefixed `VITE_` is **public**: it ships in the JS bundle. Never put a secret there.
- `.env.example` lists every variable with empty or placeholder values.

**`.gitignore` (create it in the first commit, before any key exists):**

```gitignore
# --- Secrets: never commit ---
.env
.env.*
!.env.example
*.pem
*.key
*.keystore
keystore*.json
mnemonic*.txt
secrets/

# --- Dependencies & builds ---
node_modules/
dist/
build/
.vercel/

# --- Hardhat ---
contracts/artifacts/
contracts/cache/
contracts/types/
contracts/typechain-types/
contracts/coverage/
contracts/coverage.json
contracts/ignition/deployments/chain-31337/

# --- Bot runtime ---
bot/.state/
*.log

# --- OS / IDE ---
.DS_Store
.idea/
.vscode/
```

**Secret check before every commit:**
- Abort if a `.env*` file (other than `.env.example`) is staged.
- Abort if the staged diff assigns a non-empty value to `*PRIVATE_KEY*`, `*MNEMONIC*` or `*API_KEY*`, or contains a 12/24-word phrase.
- Optionally propose `gitleaks`.

---

## 12. Git

- Run `git init` in the project root as the very first step.
- **First commit:** `.gitignore`, `.env.example`, `README.md`, `CLAUDE.md`, this spec.
- Conventional Commits: `feat:`, `fix:`, `test:`, `chore:`, `docs:`, `ci:` (scope optional, e.g. `feat(sale): …`).
- One logical step = one commit, with tests green before committing.
- Branches: `main` + `feat/<name>`, merged into `main`. Vercel builds a preview for each branch.
- The user creates the GitHub remote. Push only after confirmation. **Force push is forbidden.**

---

## 13. Hosting — Vercel

- Import the GitHub repo. Root Directory `frontend`, build command `npm run build`, output `dist`.
- Set the `VITE_*` env vars in the Vercel dashboard (Production + Preview).
- Production = `main`; every branch gets a preview URL.
- Rollback = Vercel **Instant Rollback** to the previous deployment (document it in the README).
- There is no server, so there is no healthcheck. Instead, `npm run smoke` reads `saleConfig()` via the public RPC and checks that the deployed site loads.

---

## 14. Work stages

| # | Stage | Deliverable | Sample commit |
|---|-------|-------------|---------------|
| 0 | Init | git, `.gitignore`, `.env.example`, README skeleton, workspaces | `chore: initialize monorepo` |
| 1 | Tokens | `NoesisToken`, `MockUSDC` + tests | `feat(contracts): add NOE and mUSDC tokens` |
| 2 | Sale core | `CyclicSale` rounds, phases, commit/permit + tests | `feat(sale): add cyclic rounds and commit` |
| 3 | Allocation | pro-rata, claim, refund, rollover, withdraw + tests (≥ 90%) | `feat(sale): add pro-rata claim and rollover` |
| 4 | Configurator | `sale.config.ts`, `config:check`, Ignition module, `deploy:local`, `export-abi` | `feat(deploy): add config validation and local deploy` |
| 5 | Mock bot | `mock:tick` + `demo:local` against a local node | `feat(bot): add 35-wallet mock tick` |
| 6 | Design system | tokens, fonts, logo/favicon/OG, base layout | `feat(ui): add NOESIS design system` |
| 7 | Frontend shell | wagmi/RainbowKit, network banner, chain clock | `feat(web): wallet connection and chain clock` |
| 8 | Sale UI | timeline, participation card, progress bar, validated input, claim card | `feat(web): participation and claim flows` |
| 9 | Data views | leaderboard, round history, my position | `feat(web): leaderboard and round history` |
| 10 | Content | hero, how it works, tokenomics, roadmap, FAQ, admin, footer | `feat(web): landing content and admin panel` |
| 11 | Sepolia | deploy + verify + addresses in README | `chore(deploy): deploy to Sepolia` |
| 12 | Bot in CI | `mock-bot.yml`, `ci.yml` | `ci: add hourly mock bot workflow` |
| 13 | Vercel | production + preview deploys | `chore: configure Vercel deployment` |
| 14 | Finish | `docker-compose.yml` (node + deploy + bot + frontend locally), README with a **presentation guide** | `docs: add presentation guide` |

---

## 15. Out of scope

Mainnet · real USDC / fiat · vesting · multi-tier pricing · soft cap / hard cap · whitelist / KYC · web configurator / factory · backend, database, subgraph/indexer · IPFS · security audit · multichain.

---

## 16. Acceptance criteria (Definition of Done)

- [ ] `npm test` is green and contract coverage is ≥ 90%.
- [ ] `config:check` rejects invalid dates, durations, amounts, addresses and chainIds.
- [ ] All 3 contracts are deployed and verified on Sepolia, and the on-chain parameters match `sale.config.ts`.
- [ ] On Sepolia, **≥ 3 consecutive cycles** have been populated by the bot **without redeploy**, including ≥ 1 oversubscribed round, ≥ 1 undersubscribed round, and visible rollover.
- [ ] Start and end dates of every phase are shown correctly (local time + UTC).
- [ ] Leaderboard and round history match on-chain data. Excess refunds are correct, and so is refund-only after the window.
- [ ] Every validation rule in §10.4 works. The buy, claim and refund flows work from a real MetaMask wallet.
- [ ] The site is live on Vercel and works on desktop and 375 px mobile. Lighthouse: Performance ≥ 85, Accessibility ≥ 90.
- [ ] No secrets anywhere in git history. The owner key is not used in CI.
- [ ] The README covers: description, architecture, local run (`docker compose up`), deploy, rollback, contract addresses, and a **presentation guide** (what to show in each phase, triggering `workflow_dispatch` before a demo, `demo:local` fast-forward).
