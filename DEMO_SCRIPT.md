# DEMO_SCRIPT — TapeRent (≤3 menit)

Target: ≤3 menit, satu take layar + narasi. Bahasa: Inggris (juri OKX/TapeOut), subtitle boleh Indonesia.
Rekam: browser di app demo (tab Explore + Marketplace testnet) + terminal `forge test` singkat bila sempat.

## 0:00–0:25 — Masalah (25 detik)

> "TapeOut circuits are NFTs on X Layer — including the rigs people use for PoD mining. But once you mint one, it just sits in your wallet. And if you want to *use* a circuit, you have to buy transistors and pay the tape-out fee first. There is no way to borrow one — and no on-chain record of who is allowed to use a circuit right now."
> (Tampilkan: explorer — circuit NFT di wallet pemilik, factory cpuCount 451.)

## 0:25–1:20 — Demo inti (55 detik)

> "TapeRent fixes that. I list my circuit — the NFT goes into escrow, I set a price per day."
> (Marketplace → List: mock circuit, 0.01 OKB/day, 30 hari max → Approve + List → tampilkan listing "Available".)
> "Someone rents it for 7 days — 0.07 OKB, 2.5% fee, the rest held in escrow."
> (Rent 7 hari dari wallet kedua → tampilkan "Rented by … until …".)
> "And the rental right is on-chain — any app can check it."
> (Tab Explore → Circuit lookup → `rentalOf` menunjukkan renter + expiry.)
> "If the renter leaves early, unused full days are refunded. And after expiry, *anyone* can return the circuit — so the owner always gets paid and always gets the NFT back, even if the renter disappears."
> (End early → refund terlihat; atau warp/return → NFT kembali ke owner.)

## 1:20–2:10 — Target user + bisnis (50 detik)

> "Who pays? Two sides. Owners — especially PoD rig owners — earn OKB from circuits that otherwise earn zero. Renters pay because renting for days costs a fraction of buying transistors and tape-out. We take 2.5% of each rental in OKB — no token, no subscription. And the on-chain rental record is a primitive other TapeOut apps can build on: gated mining, circuit lending for games and tools."

## 2:10–2:50 — Cara pakai TapeOut (40 detik)

> "Everything runs on real TapeOut data. The Explore tab reads the live factory on X Layer mainnet — 451 CPUs — plus circuit info and owners, with no wallet. Rentals use real circuit NFTs: our fork test lists, rents and returns the real ViperX circuit #1 on a mainnet fork. On testnet we use a clearly-labelled mock, because the TapeOut factory isn't deployed on Terigon yet."
> (Tampilkan: `forge test` 32/32 + fork 4/4, atau cuplikan test.)

## 2:50–3:00 — Penutup (10 detik)

> "TapeRent — idle circuits earn, renters use, nobody has to trust anybody. Try it on testnet today."
> (Tampilkan: link demo + repo.)

## Shot list (cek sebelum rekam)

- [ ] Tab Explore: factory stats + CPU list ter-load (butuh internet → RPC mainnet)
- [ ] Testnet: deployer funded, TapeRent + MockCircuit ter-deploy, `.env` terisi, app rebuild
- [ ] Dua wallet testnet siap (owner + renter) dengan sedikit OKB testnet
- [ ] Mock circuit sudah di-mint (tombol "Mint mock circuit")
- [ ] Suara jelas, kursor terlihat, jangan tampilkan private key/seed di layar
