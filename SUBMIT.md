# SUBMIT — OKX X Layer TapeOut Accelerate (TapeRent)

> **JANGAN submit sebelum membaca bagian "Yang belum siap".**
> Deadline: **7 Des 2026 23:59 UTC = 8 Des 06:59 WIB** (labelled *provisional* on the official page — re-check the page before submitting).
> Submit di: **https://web3.okx.com/xlayer/build-x-series** → klik tombol Submit / isi submission form di halaman itu.
> ⚠️ URL form pastinya **BELUM ditemukan** di teks halaman resmi (25 Nov 2026 — halaman hanya menyebut "submit through the submission form"). Kalau tombol/form tidak terlihat, cek juga kanal Telegram resmi yang ditautkan di halaman itu, dan jangan submit lewat link dari sumber lain yang tidak terverifikasi.

## 0. Yang sudah siap hari ini (25 Nov 2026)

- [x] Kontrak `contracts/TapeRent.sol` + `contracts/MockCircuit.sol` (compile OK, solc 0.8.24, OpenZeppelin 5.7.0)
- [x] **Test unit 32/32 lolos** (`forge test --match-contract TapeRentTest`)
- [x] **Test fork 4/4 lolos** vs X Layer mainnet (`--fork-url https://rpc.xlayer.tech`, blok 76.850.818) — baca factory live (cpuCount 451, `cpus(0)` = CPU #0, `circuitInfo(1)` = 2 in / 1 out / 0 state / 4 gates) + simulasi list/sewa/return circuit ViperX #1 ASLI di fork lokal, tanpa broadcast
- [x] **Frontend build lolos** (`npm run build`: tsc + vite; `dist/` teruji serve, HTML 200 + JS 200)
- [x] Deploy script `script/Deploy.s.sol` + throwaway deployer testnet (alamat publik `0xf0E7bCf4D299710EBB50Fa4EA946260450fBAd5C`, key di `.deployer-testnet.json` chmod 600, git-ignored)
- [x] README + DEMO_SCRIPT.md + docs/RESEARCH.md
- [x] **TapeRent TER-DEPLOY ke testnet ✅ 25 Nov 2026 ~23:44 WIB** — Terigon 1952: TapeRent `0x5D9C618932CA761EEae8749e59aB30c58E275EA3` (tx `0x6111dfa4…68c41`, blok 47166131), MockCircuit `0x18d19b1766F168a374Cd9521f669144204c9BC3A` (tx `0xf2919790…a50c005`, blok 47166131); feeBps 250 + feeRecipient/owner = deployer, terverifikasi on-chain via cast; `app/.env` terisi + `npm run build` lolos + alamat masuk bundle. Log: `deploy-log-2026-11-25.md`.
- [x] **Demo BELUM di-host** — PAKET SIAP 27 Nov 2026: `app/dist/` baru di-rebuild + terverifikasi (alamat kontrak masuk bundle), `netlify.toml` siap. Tinggal drag-and-drop `app/dist/` di https://app.netlify.com/drop (login GitHub user) — lihat §2.
- [x] **Repo di-push ke GitHub ✅ 27 Nov 2026** — https://github.com/albar30/okx-taperent (publik, 29 file, branch main). Dibuat + di-upload via API (helper custom.github); local commit `c765902`.
- [x] **Video demo ≤3 menit SELESAI ✅ 27 Nov 2026** — `demo-video.mp4` (2:55, 1920×1080, h264, 3 MB), Remotion dari DEMO_SCRIPT.md + screenshot live app (Explore 456 CPU mainnet, Marketplace testnet Fee 2.50%). Tanpa voiceover — narasi skrip tampil sebagai caption di layar (TTS Chatterbox lokal terlalu lambat di CPU + prosesnya mati saat render; jangan klaim ada voiceover). Butuh link hosting video (YouTube/drive) untuk form submit.
- [ ] **Form submit BELUM diisi** (draf teks di §3)

## 1. Deploy ke testnet Terigon (1952) — langkah user

Faucet butuh klaim via web, jadi builder tidak bisa menjalankan ini.

```bash
# 1. Klaim 0.2 OKB testnet untuk deployer 0xf0E7bCf4D299710EBB50Fa4EA946260450fBAd5C
#    di https://www.okx.com/xlayer/faucet (0.2 OKB/hari, klaim via web)
# 2. Dari repo ini:
export PATH="$HOME/.foundry/bin:$PATH"
export PRIVATE_KEY=$(python3 -c "import json; print(json.load(open('.deployer-testnet.json'))['data'][0]['private_key'])")
forge script script/Deploy.s.sol --rpc-url xlayer_testnet --broadcast
```

Catat alamat `TapeRent` dan `MockCircuit` dari output, lalu isi `app/.env`:

```bash
cp app/.env.example app/.env
# VITE_TAPERENT_TESTNET=0x...
# VITE_MOCK_CIRCUIT_TESTNET=0x...
cd app && npm run build
```

Verifikasi di explorer: `https://www.okx.com/web3/explorer/xlayer-test` (ganti path testnet sesuai explorer saat itu). Mainnet (196) **JANGAN** di-deploy tanpa preview terpisah + persetujuan eksplisit user.

## 2. Host demo

- Opsi termudah: drag-and-drop folder `app/dist/` di https://app.netlify.com/drop (login GitHub user), atau `vercel.json` di `app/` untuk Vercel.
- Isi link demo di form submit + di §3 di bawah.

## 3. Draf deskripsi untuk form submit (salin + sesuaikan alamat/link)

> **Product:** TapeRent is a rental marketplace for TapeOut circuit NFTs on X Layer. Circuit owners deposit an idle circuit NFT into escrow, set a price per day in OKB and a max rental length; renters pay per day and get an on-chain rental right — `rentalOf(circuit, tokenId)` returns (renter, expiresAt, active) — that any app can verify before letting someone use a circuit. Rent ends automatically: after expiry anyone can call `returnCircuit()` so the NFT and the escrowed rent always go back to the owner, and renters can end early with unused full days refunded fee-free, or extend up to the max. The app also has a read-only Explore tab that reads the live TapeOut factory (cpuCount, fees, first CPUs, circuit info/owner) straight from X Layer mainnet with no wallet.
>
> **Target users + how to reach them:** (1) TapeOut circuit owners — especially PoD mining rig owners whose circuits sit idle between runs; reached via the TapeOut/X Layer community, the X Layer Market, and the app's Explore tab which surfaces their circuits. (2) Users who want to *use* a circuit (try PoD mining, test a processor, build on a circuit) without buying transistors and paying the tape-out fee; reached via the same community + the demo flow on testnet. Both sides already hold the asset or the need; the marketplace is where they meet.
>
> **Revenue model:** 2.5% protocol fee on every rent payment, paid in native OKB (feeBps 250, hard-capped at 10%). No token, no oracle, no subscription. Revenue scales with rental volume; the on-chain rental-right record is also the primitive other TapeOut apps can build paid gating on.
>
> **Why users pay and keep using it:** renting for days costs a fraction of buying transistors + tape-out, and owners earn from circuits that otherwise earn zero. Every rental is escrowed and self-closing — the owner is always paid and always gets the NFT back, the renter always gets unused days refunded — so trust does not depend on the other party showing up.
>
> **TapeOut usage:** uses TapeOut circuits, contracts and on-chain data on X Layer — the live factory `0x1f09DAeFA827f02CBb40967cc91b259763760761` (cpuCount 451 at last read), CPU #0 circuits `0x839bdD6fa7A66416A609A735e11DE5411B98574e`, and real circuit NFTs such as ViperX `0xb57b56034e2dc25161e2512CfC40b24EA3bee1Fb` (fork-tested: list → rent → return of ViperX #1). TapeRent contract: `0x5D9C618932CA761EEae8749e59aB30c58E275EA3` (X Layer testnet 1952, deployed 25 Nov 2026, block 47166131, fee 2.5%). Demo uses MockCircuit on testnet only, because the TapeOut factory is not deployed on Terigon testnet (verified: no code at the factory address on chain 1952).

## 4. Checklist submit

- [ ] Deploy testnet selesai, alamat TapeRent + MockCircuit tercatat
- [ ] `app/.env` terisi, rebuild, demo di-host, link demo dicoba dari browser bersih
- [ ] Video demo ≤3 menit direkam (naskah: DEMO_SCRIPT.md), link video siap
- [ ] Repo di-push ke GitHub (publik), link repo siap
- [ ] Form di halaman resmi diisi dengan draf §3 + alamat kontrak + link demo + link video
- [ ] Simpan bukti submit (screenshot / email konfirmasi)

## 5. Yang masih butuh user (ringkas)

1. Klaim faucet testnet 0.2 OKB untuk `0xf0E7bCf4D299710EBB50Fa4EA946260450fBAd5C` + jalankan deploy script (§1) — atau beri perintah eksplisit untuk deploy.
2. Host demo (login Netlify/Vercel/GitHub user) atau izinkan drag-and-drop `app/dist/`.
3. Push repo ke GitHub (login user).
4. Rekam video demo ≤3 menit (naskah siap) — atau setujui rekaman layar dari browser.
5. Isi + kirim form submit di halaman resmi (butuh login/identitas user; finalis wajib hadir Demo Day offline — risiko dicatat di docs/RESEARCH.md).
