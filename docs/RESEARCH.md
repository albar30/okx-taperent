# RESEARCH — TapeRent / OKX X Layer TapeOut Accelerate

Semua fakta di bawah dibaca langsung (RPC / halaman resmi), bukan dari dokumentasi sekunder. Tanggal baca: **25 Nov 2026** (kecuali dinyatakan lain).

## 1. Hackathon resmi

- Sumber: https://web3.okx.com/xlayer/build-x-series (teks halaman dibaca 25 Nov 2026, 15:06 UTC).
- Nama: **X Layer TapeOut Accelerate** (Build X Series). Total hadiah **100.000 USDT**: 1st 20.000 USDT ×1, 2nd 10.000 ×5, 3rd 6.000 ×5. Pool "akan terus bertambah" dari founder/komunitas TapeOut — jangan klaim angka di luar 100.000 USDT.
- Deadline: **7 Des 2026 23:59 UTC = 8 Des 06:59 WIB**. Halaman + FAQ + Terms menyebut deadline ini **provisional** ("The deadline is provisional; the official event page will confirm the final date") — cek ulang halaman sebelum submit.
- Gratis, individu/tim boleh, online. **Finalis wajib hadir Demo Day offline** (shortlisted teams attending offline Demo Day).
- Syarat: proyek harus pakai TapeOut circuits/kontrak/data on-chain di X Layer, atau jalan di X Layer DeWEB. Interface/komputasi boleh di luar circuit; boleh pakai processor/circuit/tools TapeOut yang sudah ada; proyek harus pakai circuits/kontrak/data on-chain TapeOut di X Layer + sertakan alamat relevan.
- Deskripsi submit wajib menjelaskan: produk, target user + cara menjangkau, model revenue, kenapa user mau bayar dan terus pakai.
- Penilaian: User Value & Commercial Potential, Innovation, Ecosystem Integration, Product Readiness & UX, Demo Video ≤3 menit (masalah, demo fitur inti, target user + bisnis, cara pakai TapeOut).
- Hadiah dibayar **bertahap berbasis milestone** setelah verifikasi eligibility; pemenang mungkin diminta cek identitas; wallet penerima harus self-custodial. Syarat peserta ≥18 tahun / usia dewasa hukum; "Restricted Persons" di bawah X Layer ToS tidak eligible.
- **URL form submit PASTINYA BELUM ditemukan** di teks halaman (25 Nov 2026). Halaman hanya menyebut "submit through the submission form" + tautan kanal Telegram untuk pertanyaan. Langkah submit di SUBMIT.md: buka halaman resmi, klik Submit. Jangan submit lewat link tak terverifikasi.

## 2. X Layer — chain + RPC (diverifikasi live 25 Nov 2026)

| Jaringan | Chain ID | RPC | Status 25 Nov |
|---|---|---|---|
| X Layer mainnet | 196 | https://rpc.xlayer.tech | Hidup; blok 76.851.069 saat fork test |
| X Layer testnet "Terigon" | 1952 | https://testrpc.xlayer.tech/terigon | Hidup; `cast chain-id` = 1952 |
| Faucet testnet | — | https://www.okx.com/xlayer/faucet | 0,2 OKB/hari, klaim via web |
| Explorer | — | https://www.okx.com/web3/explorer/xlayer | — |

Gas: OKB native di kedua jaringan.

## 3. TapeOut di X Layer mainnet (dibaca live via RPC 25 Nov 2026)

- Factory (proxy EIP-1967 UUPS): `0x1f09DAeFA827f02CBb40967cc91b259763760761`
  - `cpuCount()` = **451**; `cpus(0)` = `0x839bdD6fa7A66416A609A735e11DE5411B98574e`
  - `deployFee()` = **10.000.000 wei** (0,00001 OKB); `protocolFee()` = **1.000.000 wei**
  - `isSealed()` = false; `owner()` = `0xB3D85b42a045c1a88d800cad0f55d2566a4d3138`
- CPU #0 "OnlyTestXLayer" circuits: `0x839bdD6fa7A66416A609A735e11DE5411B98574e`
  - `nextId()` = **105**; `TAPEOUT_FEE()` = **0,005214 OKB**; `circuitInfo(1)` = (nIn 2, nOut 1, nState 0, gateCount 4)
- Contoh circuit NFT nyata: processor ViperX `0xb57b56034e2dc25161e2512CfC40b24EA3bee1Fb`, `ownerOf(1)` = `0x9f718b338Ccc69B6AC211Dc8239548E43095813a`
- Market X Layer: `0xd89f358c48a7B632c9845af2a02A32eB90DD75DB`; token BEM: `0x60e62Efa9405d6873C5deaBD4E6CC91c25363952`
- Circuits = ERC-721 (ownerOf, transferFrom, safeTransferFrom, approvals; TIDAK ada Enumerable; tokenURI kosong). Fungsi: `tapeout(bytes netlist, uint32 nIn, uint32 nOut)` payable fee exact; `circuitInfo(id)`; `netlist(id)`; `eval(id, inputs)` kombinasional; `step(id, state, inputs)` sequential; `nextId()` = id terakhir.

### Diskrepansi fee (penting — jangan hardcode fee)

- `deployFee` tercatat **0,0066 OKB** di fork 4 Okt 2026, tapi dibaca live **10.000.000 wei (0,00001 OKB)** pada 25 Nov — implementasi factory berubah 23 Okt.
- CPU #0 `TAPEOUT_FEE` dulu **0,0013 OKB**, dibaca live **0,005214 OKB** pada 25 Nov.
- Kesimpulan: owner mengubah fee dari waktu ke waktu. TapeRent tidak membaca/membayar fee TapeOut sama sekali (hanya memakai NFT circuit yang sudah ada), dan frontend membaca fee factory secara live. Jangan pernah hardcode angka fee TapeOut.

### Testnet

- **Factory TIDAK ada di testnet 1952**: `eth_getCode` di alamat factory = `0x` (diverifikasi 25 Nov 2026). Jadi demo testnet memakai `MockCircuit` (ERC-721 yang meniru interface circuits) — diberi nama jelas MOCK, jangan klaim sebagai circuit TapeOut asli.

## 4. Risiko

1. **Kontrak TapeOut masih test-phase, upgradeable, BELUM diaudit, owner bisa ubah fee.** Ditulis di README + footer app.
2. **TapeRent sendiri unaudited** (kode hackathon). Jangan pakai untuk circuit bernilai tinggi tanpa audit profesional.
3. **Pembayaran hadiah berbasis milestone** + verifikasi eligibility/identitas — hadiah bukan tunai langsung penuh diumumkan menang.
4. **Demo Day offline untuk finalis** — butuh kehadiran fisik (biaya/waktu perjalanan belum diketahui).
5. **Deadline provisional** — bisa berubah; cek halaman resmi sebelum submit.
6. **Form submit belum ditemukan URL pastinya** — risiko salah jalur submit; hanya pakai tombol/form di halaman resmi.
7. TapeRent mengandalkan RPC publik X Layer untuk frontend; bila RPC down, tab Explore gagal load (ditangani dengan pesan error, bukan data palsu).
8. `MockCircuit.mintDemo` gratis dan `withdrawFees` tanpa akses kontrol — sengaja, karena ini kontrak demo testnet tanpa nilai; JANGAN deploy mock ke mainnet.

## 5. Verifikasi yang sudah dilakukan (25 Nov 2026)

| Cek | Hasil |
|---|---|
| `forge build` (solc 0.8.24, OZ 5.7.0) | OK |
| `forge test --match-contract TapeRentTest` | **32/32 lolos** |
| `forge test --match-contract TapeRentForkTest --fork-url https://rpc.xlayer.tech` | **4/4 lolos** (blok fork 76.850.818): baca factory live + list/sewa/return ViperX #1 asli di fork lokal, tanpa broadcast |
| `npm run build` (app) | OK (tsc + vite); `dist/` teruji serve (HTML 200, JS 200) |
| Testnet RPC + factory tidak ada di 1952 | Terverifikasi (`cast chain-id` 1952, `eth_getCode` 0x) |
| Deploy testnet / mainnet | **TIDAK dilakukan** (faucet butuh klaim web; mainnet butuh approval terpisah) |
| Submit form | **TIDAK dilakukan** (URL form belum ditemukan; hanya draf di SUBMIT.md) |
