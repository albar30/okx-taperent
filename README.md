# TapeRent — Rent TapeOut Circuit NFTs on X Layer

> **Idle TapeOut circuits earn nothing. TapeRent lets owners rent them out for OKB, and lets renters use a circuit without buying transistors + tape-out.**
> Built for the **OKX X Layer TapeOut Accelerate** hackathon (Build X Series) — 100,000 USDT prize pool, submit by **7 Dec 2026 23:59 UTC** (8 Dec 06:59 WIB).

- **Hackathon:** https://web3.okx.com/xlayer/build-x-series
- **Status (25 Nov 2026):** contracts + tests + frontend built and verified. **TapeRent DEPLOYED to testnet ✅ 25 Nov 2026 ~23:44 WIB** — `0x5D9C618932CA761EEae8749e59aB30c58E275EA3` (block 47166131), MockCircuit `0x18d19b1766F168a374Cd9521f669144204c9BC3A`. See [deploy-log-2026-11-25.md](deploy-log-2026-11-25.md).
- **No backend, no server.** The frontend talks straight to X Layer RPC via viem.

## The problem

TapeOut circuits are ERC-721 NFTs on X Layer — including rigs used for PoD mining. Once minted, most sit idle in their owner's wallet. Meanwhile a new user who wants to *use* a circuit must buy transistors and pay the tape-out fee first. There is no way to borrow one, and no on-chain record of who is allowed to use a circuit right now.

## The product

A rental marketplace for TapeOut circuit NFTs:

1. **Owner lists** a circuit: the NFT goes into escrow in `TapeRent`, with a price per day (OKB) and a max rental length.
2. **Renter pays** `pricePerDay × days` in native OKB. A 2.5% protocol fee goes to the fee recipient; the rest is held in escrow.
3. **The rental right is on-chain**: `rentalOf(circuit, tokenId)` returns `(renter, expiresAt, active)` — any app (a PoD miner, a game, a tool) can check who may use a circuit without trusting TapeRent's UI.
4. **Ending**: after expiry anyone can call `returnCircuit()` — the NFT goes back to the owner and escrowed rent is paid out, so nothing can get stuck if the renter disappears. The renter can end early (`endEarly()`) and gets unused **full days refunded fee-free**. The renter can also `extend()` up to `maxDays`. The owner can `cancelListing()` while unrented.

## Why this uses TapeOut for real

- Reads the **live TapeOut factory** on X Layer mainnet (chain 196): `cpuCount`, `cpus(i)`, fees — shown in the app's Explore tab with no wallet.
- Rents **real circuit NFTs** (ERC-721): the fork test lists, rents and returns the real ViperX processor circuit #1 on a mainnet fork, impersonating its owner.
- `rentalOf` / `isRented` expose TapeOut circuit usage rights as on-chain data other ecosystem apps can consume.

## Repo layout

```
okx-tapeout/
├── contracts/
│   ├── TapeRent.sol      # rental marketplace (escrow, 2.5% fee, refunds)
│   └── MockCircuit.sol   # DEMO-ONLY ERC-721 mimicking the circuit interface (testnet)
├── test/
│   ├── TapeRent.t.sol        # 32 unit tests
│   └── TapeRentFork.t.sol    # 4 fork tests vs X Layer mainnet (read-only + local sim)
├── script/Deploy.s.sol   # deploy TapeRent (+ MockCircuit on testnet)
├── app/                  # Vite + React + viem frontend (static, no backend)
├── docs/RESEARCH.md      # every verified fact, source + date + discrepancies
├── SUBMIT.md             # submission checklist + draft description for the form
└── DEMO_SCRIPT.md        # ≤3 min demo video script
```

## Contracts (verified addresses)

| Contract | Chain | Address |
|---|---|---|
| TapeOut Factory (proxy UUPS) | X Layer mainnet 196 | `0x1f09DAeFA827f02CBb40967cc91b259763760761` |
| CPU #0 "OnlyTestXLayer" circuits | 196 | `0x839bdD6fa7A66416A609A735e11DE5411B98574e` |
| ViperX processor (example circuit) | 196 | `0xb57b56034e2dc25161e2512CfC40b24EA3bee1Fb` |
| X Layer Market | 196 | `0xd89f358c48a7B632c9845af2a02A32eB90DD75DB` |
| **TapeRent** | testnet 1952 | **0x5D9C618932CA761EEae8749e59aB30c58E275EA3** (deployed 25 Nov 2026, block 47166131, fee 2.5%) |
| **MockCircuit** (demo only) | testnet 1952 | **0x18d19b1766F168a374Cd9521f669144204c9BC3A** (deployed 25 Nov 2026, block 47166131) |

X Layer mainnet: chain 196, RPC `https://rpc.xlayer.tech`, gas OKB.
Testnet "Terigon": chain 1952, RPC `https://testrpc.xlayer.tech/terigon`, faucet `https://www.okx.com/xlayer/faucet` (0.2 OKB/day, web claim). **The TapeOut factory does NOT exist on testnet** (verified: `eth_getCode` = `0x`) — that is why the demo uses `MockCircuit`.

## Run the tests

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract TapeRentTest        # 32 unit tests
forge test --match-contract TapeRentForkTest --fork-url https://rpc.xlayer.tech   # 4 fork tests
```

Results on 25 Nov 2026: **32/32 unit passed, 4/4 fork passed** (fork block 76,850,818). The fork test impersonates the real owner of ViperX #1 (`0x9f718b338Ccc69B6AC211Dc8239548E43095813a`) to list the real circuit in TapeRent, rents it from another account, warps past expiry and returns it — all locally, nothing broadcast.

Note: `forge test` without `--fork-url` fails the 4 fork tests (no factory code on a local chain) — that is expected; run them with the fork flag.

## Run the frontend

```bash
cd app
npm install
npm run build   # must pass (tsc + vite)
npm run dev     # http://localhost:5173
```

- **Explore tab** works with no wallet: live factory stats + first 8 CPUs + circuit lookup (`circuitInfo` / `ownerOf` / rental status).
- **Marketplace tab** needs a wallet (MetaMask / OKX Wallet) and a deployed TapeRent address:
  - copy `app/.env.example` to `app/.env`, fill `VITE_TAPERENT_TESTNET` / `VITE_MOCK_CIRCUIT_TESTNET` after deploying, rebuild.
  - On testnet: mint a free mock circuit, then list / rent / extend / end early / return / cancel — all on-chain.
- Hosting: static `app/dist/` — `netlify.toml` (root) and `app/vercel.json` included; drag-and-drop `app/dist/` at https://app.netlify.com/drop works.

## Deploy (user step — NOT run by the builder)

```bash
export PRIVATE_KEY=<throwaway testnet deployer key>   # never hardcode, never commit
forge script script/Deploy.s.sol --rpc-url xlayer_testnet --broadcast
```

A throwaway testnet deployer already exists at `.deployer-testnet.json` (chmod 600, git-ignored), address `0xf0E7bCf4D299710EBB50Fa4EA946260450fBAd5C` — fund it from the web faucet (0.2 OKB/day), then run the script. **Do NOT deploy to mainnet (196) without a separate preview + explicit user approval.**

## Revenue model

2.5% of every rent payment (`feeBps = 250`, capped at 10%, changeable by the contract owner). No token, no oracle, only native OKB. Renters pay because renting a circuit for days is far cheaper than buying transistors + tape-out; owners earn because idle circuits otherwise earn zero. The fee scales with rental volume, and the on-chain rental-right record (`rentalOf`) is the primitive other TapeOut apps can build on (gated PoD mining, circuit lending for games/tools).

## Risks — read before using

- ⚠️ **TapeOut contracts are still in a test phase, upgradeable and UNAUDITED, and their owner can change fees at any time.** TapeOut fees were observed changing (CPU #0 `TAPEOUT_FEE` 0.0013 → 0.005214 OKB; factory `deployFee` 0.0066 OKB in an old fork → 10,000,000 wei = 0.00001 OKB when read live). TapeRent reads fees live and never hardcodes them — but a fee change can still break assumptions.
- ⚠️ **TapeRent itself is unaudited hackathon code.** Do not use with high-value circuits without a professional audit.
- ⚠️ Hackathon terms: prizes are paid in stages against milestones after eligibility verification (winners may need identity checks); shortlisted teams must attend an **offline Demo Day**; the 7 Dec 2026 deadline is labelled **provisional** on the official page. See [docs/RESEARCH.md](docs/RESEARCH.md).
