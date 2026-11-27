# Deploy log — TapeRent ke X Layer testnet (Terigon)

**Tanggal:** 25 Nov 2026 ~23:44 WIB
**Chain:** X Layer testnet Terigon, chain ID 1952 (RPC https://testrpc.xlayer.tech/terigon)
**Deployer (throwaway testnet):** 0xf0E7bCf4D299710EBB50Fa4EA946260450fBAd5C
**Faucet:** 0,2 OKB diklaim user dari https://www.okx.com/xlayer/faucet (saldo terverifikasi on-chain sebelum deploy: 0,2 OKB persis = 200000000000000000 wei)
**Perintah:** `forge script script/Deploy.s.sol --rpc-url xlayer_testnet --broadcast` (forge 1.9.0, solc 0.8.24)
**Biaya deploy aktual:** ~0,0000637 OKB (saldo deployer setelah deploy: 0,199936273916813696 OKB)

## Kontrak ter-deploy (terverifikasi on-chain)

| Kontrak | Alamat | Tx hash | Blok | Gas | Status |
|---|---|---|---|---|---|
| TapeRent | 0x5D9C618932CA761EEae8749e59aB30c58E275EA3 | 0x6111dfa47116229c883f32c7771ecf17857959a1348ccf4fe95daebc6e868c41 | 47166131 | 1.822.581 | 1 (success) |
| MockCircuit (DEMO ONLY) | 0x18d19b1766F168a374Cd9521f669144204c9BC3A | 0xf2919790d1b22eab720d753e5940d6c2c4a65b2de68148fce8ad607d5a50c005 | 47166131 | 1.363.723 | 1 (success) |

**Verifikasi on-chain via `cast` (RPC testnet):**
- `cast code` kedua alamat: bytecode ada (bukan 0x).
- `feeBps()` = 250 (2,5%) — sesuai desain.
- `feeRecipient()` = 0xf0E7bCf4D299710EBB50Fa4EA946260450fBAd5C (deployer).
- `owner()` = 0xf0E7bCf4D299710EBB50Fa4EA946260450fBAd5C (deployer).

**Explorer testnet:** https://www.okx.com/web3/explorer/xlayer-test (cari alamat/tx di atas).

## App

- `app/.env` dibuat dari `.env.example`, terisi:
  - `VITE_TAPERENT_TESTNET=0x5D9C618932CA761EEae8749e59aB30c58E275EA3`
  - `VITE_MOCK_CIRCUIT_TESTNET=0x18d19b1766F168a374Cd9521f669144204c9BC3A`
  - `VITE_TAPERENT_MAINNET=` (kosong — mainnet TIDAK di-deploy)
- `npm run build` di `app/` **lolos** (tsc + vite, built 1,13 detik; hanya warning chunk-size + configLoader yang sudah ada sebelumnya).
- Kedua alamat terkonfirmasi masuk ke bundle `dist/assets/index-DP_HELbt.js` (grep cocok).

## Yang masih butuh user

1. Host demo: drag-and-drop folder `app/dist/` di https://app.netlify.com/drop (login GitHub user) atau Vercel — lalu coba link demo dari browser bersih.
2. Push repo ke GitHub (login user) — repo sudah git, `.deployer-testnet.json` di-gitignore, private key tidak pernah dicetak.
3. Rekam video demo ≤3 menit (naskah: DEMO_SCRIPT.md).
4. Isi + kirim form submit di halaman resmi (deadline 8 Des 06:59 WIB, label provisional; URL form belum ditemukan di teks halaman — buka halaman resmi dan klik Submit).
5. Mainnet (196) JANGAN di-deploy tanpa preview terpisah + persetujuan eksplisit user.

**Catatan:** TapeOut factory TIDAK ada di testnet Terigon (kode 0x), jadi demo memakai MockCircuit — sesuai desain. Private key deployer tetap di `.deployer-testnet.json` (chmod 600, git-ignored) dan tidak pernah dicetak ke output/log/chat.
