import { useCallback, useEffect, useMemo, useState } from "react";
import {
  createWalletClient,
  custom,
  formatEther,
  parseEther,
  type Address,
  type PublicClient,
} from "viem";
import {
  CPU0_CIRCUIT,
  FAUCET_URL,
  MOCK_CIRCUIT_TESTNET,
  TAPERENT_MAINNET,
  TAPERENT_TESTNET,
  TAPEOUT_FACTORY,
  circuitAbi,
  factoryAbi,
  fmtDate,
  fmtOkb,
  mainnetClient,
  mockCircuitAbi,
  shortAddr,
  tapeRentAbi,
  testnetClient,
  xlayerMainnet,
  xlayerTestnet,
} from "./lib/tapeout";

type ChainId = 196 | 1952;

interface CpuRow {
  index: number;
  address: Address;
  name: string;
  symbol: string;
  circuits: string;
}

interface ListingRow {
  id: bigint;
  circuit: Address;
  tokenId: bigint;
  owner: Address;
  renter: Address;
  pricePerDay: bigint;
  maxDays: bigint;
  rentedDays: bigint;
  expiresAt: bigint;
  escrow: bigint;
  active: boolean;
}

function getEthereum(): any {
  return (window as any).ethereum;
}

export default function App() {
  const [chainId, setChainId] = useState<ChainId>(196);
  const [tab, setTab] = useState<"explore" | "market">("explore");
  const [account, setAccount] = useState<Address | null>(null);
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  // Explore state
  const [factory, setFactory] = useState<{ cpuCount: string; deployFee: string; protocolFee: string; sealed: boolean; owner: string } | null>(null);
  const [cpus, setCpus] = useState<CpuRow[]>([]);
  const [exploreLoading, setExploreLoading] = useState(false);
  const [lookupAddr, setLookupAddr] = useState<string>(CPU0_CIRCUIT);
  const [lookupId, setLookupId] = useState("1");
  const [lookupResult, setLookupResult] = useState("");

  // Marketplace state
  const [listings, setListings] = useState<ListingRow[]>([]);
  const [feeInfo, setFeeInfo] = useState("");
  const [listCircuitAddr, setListCircuitAddr] = useState("");
  const [listTokenId, setListTokenId] = useState("");
  const [listPrice, setListPrice] = useState("0.01");
  const [listMaxDays, setListMaxDays] = useState("30");
  const [rentDays, setRentDays] = useState<{ [id: string]: string }>({});
  const [extendDays, setExtendDays] = useState<{ [id: string]: string }>({});

  const isMainnet = chainId === 196;
  const client: PublicClient = isMainnet ? (mainnetClient as PublicClient) : (testnetClient as PublicClient);
  const tapeRentAddr = (isMainnet ? TAPERENT_MAINNET : TAPERENT_TESTNET) as Address | "";
  const mockAddr = MOCK_CIRCUIT_TESTNET as Address | "";
  const chain = isMainnet ? xlayerMainnet : xlayerTestnet;

  const explorerBase = "https://www.okx.com/web3/explorer/xlayer";

  const walletClient = useMemo(() => {
    const eth = getEthereum();
    if (!eth || !account) return null;
    return createWalletClient({ chain, transport: custom(eth), account });
  }, [account, chain]);

  async function switchChain(id: ChainId) {
    setChainId(id);
    setListings([]);
    setFeeInfo("");
    const eth = getEthereum();
    if (eth && account) {
      try {
        await eth.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: `0x${id.toString(16)}` }],
        });
      } catch (e: any) {
        // 4902 = chain not added to the wallet; add it.
        if (e?.code === 4902) {
          await eth.request({
            method: "wallet_addEthereumChain",
            params: [
              {
                chainId: `0x${id.toString(16)}`,
                chainName: id === 196 ? "X Layer" : "X Layer Testnet (Terigon)",
                nativeCurrency: { name: "OKB", symbol: "OKB", decimals: 18 },
                rpcUrls: [id === 196 ? "https://rpc.xlayer.tech" : "https://testrpc.xlayer.tech/terigon"],
                blockExplorerUrls: [explorerBase],
              },
            ],
          });
        }
      }
    }
  }

  async function connect() {
    const eth = getEthereum();
    if (!eth) {
      setStatus("No injected wallet found. Install MetaMask or OKX Wallet first.");
      return;
    }
    setBusy(true);
    try {
      const accounts = (await eth.request({ method: "eth_requestAccounts" })) as string[];
      setAccount(accounts[0] as Address);
      await switchChain(chainId);
      setStatus(`Connected ${shortAddr(accounts[0])}`);
    } catch (e: any) {
      setStatus(`Connect failed: ${e?.shortMessage ?? e?.message ?? e}`);
    } finally {
      setBusy(false);
    }
  }

  // ---------------- Explore (read-only, no wallet) ----------------

  const loadExplore = useCallback(async () => {
    setExploreLoading(true);
    try {
      const [cpuCount, deployFee, protocolFee, sealed, owner] = await Promise.all([
        mainnetClient.readContract({ address: TAPEOUT_FACTORY, abi: factoryAbi, functionName: "cpuCount" }),
        mainnetClient.readContract({ address: TAPEOUT_FACTORY, abi: factoryAbi, functionName: "deployFee" }),
        mainnetClient.readContract({ address: TAPEOUT_FACTORY, abi: factoryAbi, functionName: "protocolFee" }),
        mainnetClient.readContract({ address: TAPEOUT_FACTORY, abi: factoryAbi, functionName: "isSealed" }),
        mainnetClient.readContract({ address: TAPEOUT_FACTORY, abi: factoryAbi, functionName: "owner" }),
      ]);
      setFactory({
        cpuCount: cpuCount.toString(),
        deployFee: fmtOkb(deployFee),
        protocolFee: fmtOkb(protocolFee),
        sealed,
        owner,
      });
      const rows: CpuRow[] = [];
      for (let i = 0; i < 8; i++) {
        const addr = await mainnetClient.readContract({ address: TAPEOUT_FACTORY, abi: factoryAbi, functionName: "cpus", args: [BigInt(i)] });
        let name = "—";
        let symbol = "—";
        let circuits = "—";
        try {
          [name, symbol, circuits] = await Promise.all([
            mainnetClient.readContract({ address: addr, abi: circuitAbi, functionName: "name" }),
            mainnetClient.readContract({ address: addr, abi: circuitAbi, functionName: "symbol" }),
            mainnetClient.readContract({ address: addr, abi: circuitAbi, functionName: "nextId" }).then((n) => (Number(n) - 1).toString()),
          ]);
        } catch {
          /* some circuits may not expose name/symbol */
        }
        rows.push({ index: i, address: addr, name, symbol, circuits });
      }
      setCpus(rows);
    } catch (e: any) {
      setStatus(`Explore load failed: ${e?.shortMessage ?? e?.message ?? e}`);
    } finally {
      setExploreLoading(false);
    }
  }, []);

  useEffect(() => {
    loadExplore();
  }, [loadExplore]);

  async function lookupCircuit() {
    setLookupResult("Reading…");
    try {
      const addr = lookupAddr as Address;
      const id = BigInt(lookupId);
      const [nIn, nOut, nState, gates] = await mainnetClient.readContract({
        address: addr, abi: circuitAbi, functionName: "circuitInfo", args: [id],
      });
      const owner = await mainnetClient.readContract({ address: addr, abi: circuitAbi, functionName: "ownerOf", args: [id] });
      let rental = "";
      if (tapeRentAddr) {
        const [renter, exp, active] = await (isMainnet ? mainnetClient : testnetClient).readContract({
          address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "rentalOf", args: [addr, id],
        });
        rental = active
          ? `\nRented by ${renter} until ${fmtDate(exp)}`
          : `\nNot currently rented on TapeRent.`;
      }
      setLookupResult(
        `circuitInfo(#${id}): ${nIn} in, ${nOut} out, ${nState} state, ${gates} gates\nOwner: ${owner}${rental}`,
      );
    } catch (e: any) {
      setLookupResult(`Lookup failed: ${e?.shortMessage ?? e?.message ?? e}`);
    }
  }

  // ---------------- Marketplace ----------------

  const loadMarket = useCallback(async () => {
    if (!tapeRentAddr) return;
    try {
      const [feeBps, feeRecipient, nextId] = await Promise.all([
        client.readContract({ address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "feeBps" }),
        client.readContract({ address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "feeRecipient" }),
        client.readContract({ address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "nextListingId" }),
      ]);
      setFeeInfo(`Fee ${(Number(feeBps) / 100).toFixed(2)}% → ${shortAddr(feeRecipient)} · ${Number(nextId) - 1} listings ever`);
      const rows: ListingRow[] = [];
      const total = Number(nextId) - 1;
      for (let i = Math.max(1, total - 24); i <= total; i++) {
        const l = await client.readContract({
          address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "getListing", args: [BigInt(i)],
        });
        rows.push({
          id: BigInt(i),
          circuit: l.circuit, tokenId: l.tokenId, owner: l.owner, renter: l.renter,
          pricePerDay: l.pricePerDay, maxDays: l.maxDays, rentedDays: l.rentedDays,
          expiresAt: l.expiresAt, escrow: l.escrow, active: l.active,
        });
      }
      setListings(rows.reverse());
    } catch (e: any) {
      setStatus(`Market load failed: ${e?.shortMessage ?? e?.message ?? e}`);
    }
  }, [client, tapeRentAddr]);

  useEffect(() => {
    if (tab === "market") loadMarket();
  }, [tab, loadMarket]);

  async function sendWrite(fn: () => Promise<`0x${string}`>) {
    if (!walletClient || !account) {
      setStatus("Connect your wallet first.");
      return;
    }
    setBusy(true);
    setStatus("Waiting for wallet confirmation…");
    try {
      const hash = await fn();
      setStatus(`Sent: ${hash} — waiting for confirmation…`);
      await client.waitForTransactionReceipt({ hash });
      setStatus(`Confirmed: ${hash}`);
      loadMarket();
    } catch (e: any) {
      setStatus(`Failed: ${e?.shortMessage ?? e?.message ?? e}`);
    } finally {
      setBusy(false);
    }
  }

  async function doListCircuit() {
    if (!walletClient || !account || !tapeRentAddr) return;
    const circuit = listCircuitAddr as Address;
    const tokenId = BigInt(listTokenId);
    const price = parseEther(listPrice);
    const maxDays = BigInt(listMaxDays);
    setBusy(true);
    setStatus("Step 1/2: approving TapeRent to hold your circuit…");
    try {
      const approveHash = await walletClient.writeContract({
        address: circuit, abi: circuitAbi, functionName: "approve",
        args: [tapeRentAddr as Address, tokenId], account, chain,
      });
      await client.waitForTransactionReceipt({ hash: approveHash });
      setStatus("Step 2/2: listing…");
      const hash = await walletClient.writeContract({
        address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "list",
        args: [circuit, tokenId, price, maxDays], account, chain,
      });
      setStatus(`Listed: ${hash}`);
      await client.waitForTransactionReceipt({ hash });
      setStatus(`Listed! ${hash}`);
      loadMarket();
    } catch (e: any) {
      setStatus(`List failed: ${e?.shortMessage ?? e?.message ?? e}`);
    } finally {
      setBusy(false);
    }
  }

  async function mintMock() {
    if (!walletClient || !account || !mockAddr) return;
    await sendWrite(() =>
      walletClient.writeContract({
        address: mockAddr as Address, abi: mockCircuitAbi, functionName: "mintDemo",
        args: [2, 1], account, chain,
      }),
    );
  }

  // ---------------- Render ----------------

  return (
    <div className="page">
      <header>
        <h1>🎛️ TapeRent</h1>
        <p className="tagline">Rent TapeOut circuit NFTs on X Layer — owners earn OKB from idle circuits, renters get on-chain rental rights without buying.</p>
        <div className="row">
          <button className={isMainnet ? "active" : ""} onClick={() => switchChain(196)}>X Layer Mainnet (196)</button>
          <button className={!isMainnet ? "active" : ""} onClick={() => switchChain(1952)}>Testnet Terigon (1952)</button>
          {account ? (
            <span className="pill">Connected: {shortAddr(account)}</span>
          ) : (
            <button onClick={connect} disabled={busy}>Connect Wallet (MetaMask / OKX Wallet)</button>
          )}
        </div>
        {!isMainnet && (
          <p className="note">
            Testnet has no real TapeOut factory — use the <b>MockCircuit (DEMO ONLY)</b> below. Get test OKB at{" "}
            <a href={FAUCET_URL} target="_blank" rel="noreferrer">{FAUCET_URL}</a> (0.2 OKB/day).
          </p>
        )}
      </header>

      <nav className="row">
        <button className={tab === "explore" ? "active" : ""} onClick={() => setTab("explore")}>Explore TapeOut</button>
        <button className={tab === "market" ? "active" : ""} onClick={() => setTab("market")}>Marketplace</button>
      </nav>

      {status && <p className="status">{status}</p>}

      {tab === "explore" && (
        <section>
          <h2>Live TapeOut factory — X Layer mainnet</h2>
          <p className="note">Read straight from the chain (no wallet needed). Factory: <code>{shortAddr(TAPEOUT_FACTORY)}</code></p>
          {factory ? (
            <div className="grid">
              <div className="card"><b>{factory.cpuCount}</b><span>CPUs created</span></div>
              <div className="card"><b>{factory.deployFee} OKB</b><span>deployFee (live — changes!)</span></div>
              <div className="card"><b>{factory.protocolFee} OKB</b><span>protocolFee (live)</span></div>
              <div className="card"><b>{factory.sealed ? "Sealed" : "Open"}</b><span>factory sealed?</span></div>
              <div className="card"><b>{shortAddr(factory.owner)}</b><span>factory owner</span></div>
            </div>
          ) : (
            <p>{exploreLoading ? "Loading…" : "Failed to load."}</p>
          )}
          <button onClick={loadExplore} disabled={exploreLoading}>Refresh</button>

          <h3>First CPUs</h3>
          <table>
            <thead><tr><th>#</th><th>Name</th><th>Symbol</th><th>Circuits</th><th>Contract</th></tr></thead>
            <tbody>
              {cpus.map((c) => (
                <tr key={c.index}>
                  <td>{c.index}</td><td>{c.name}</td><td>{c.symbol}</td><td>{c.circuits}</td>
                  <td><a href={`${explorerBase}/address/${c.address}`} target="_blank" rel="noreferrer">{shortAddr(c.address)}</a></td>
                </tr>
              ))}
            </tbody>
          </table>

          <h3>Circuit lookup</h3>
          <div className="row">
            <input value={lookupAddr} onChange={(e) => setLookupAddr(e.target.value)} placeholder="Circuit contract address" size={44} />
            <input value={lookupId} onChange={(e) => setLookupId(e.target.value)} placeholder="Token ID" size={6} />
            <button onClick={lookupCircuit}>Look up</button>
          </div>
          {lookupResult && <pre>{lookupResult}</pre>}
        </section>
      )}

      {tab === "market" && (
        <section>
          <h2>Rental marketplace — {isMainnet ? "X Layer mainnet" : "Terigon testnet"}</h2>
          {!tapeRentAddr ? (
            <div className="card warn">
              <b>TapeRent is not deployed on this chain yet.</b>
              <p>Deploy it first: <code>forge script script/Deploy.s.sol --rpc-url {isMainnet ? "xlayer" : "xlayer_testnet"} --broadcast</code> (testnet only for now — mainnet needs a separate approval), then set{" "}
              <code>{isMainnet ? "VITE_TAPERENT_MAINNET" : "VITE_TAPERENT_TESTNET"}</code> in <code>app/.env</code> and rebuild.</p>
            </div>
          ) : (
            <>
              <p className="note">TapeRent: <code>{tapeRentAddr}</code> · {feeInfo}</p>

              {!isMainnet && mockAddr && (
                <div className="card">
                  <b>Demo: mint a mock circuit</b>
                  <p>MockCircuit is a DEMO-ONLY stand-in (testnet has no real TapeOut factory). Mint one, then list it below.</p>
                  <button onClick={mintMock} disabled={busy || !account}>Mint mock circuit (free)</button>
                </div>
              )}

              <h3>List your circuit</h3>
              <div className="row">
                <input value={listCircuitAddr} onChange={(e) => setListCircuitAddr(e.target.value)} placeholder="Circuit contract address" size={44} />
                <input value={listTokenId} onChange={(e) => setListTokenId(e.target.value)} placeholder="Token ID" size={6} />
                <input value={listPrice} onChange={(e) => setListPrice(e.target.value)} placeholder="OKB / day" size={8} />
                <input value={listMaxDays} onChange={(e) => setListMaxDays(e.target.value)} placeholder="Max days" size={6} />
                <button onClick={doListCircuit} disabled={busy || !account}>Approve + List</button>
              </div>
              {!isMainnet && mockAddr && (
                <p className="note">Demo shortcut: paste the mock address <code>{mockAddr}</code> as the circuit contract.</p>
              )}

              <h3>Listings</h3>
              <button onClick={loadMarket}>Refresh listings</button>
              {listings.length === 0 && <p>No listings found (yet).</p>}
              {listings.map((l) => {
                const rented = l.renter !== "0x0000000000000000000000000000000000000000";
                const expired = rented && Date.now() / 1000 >= Number(l.expiresAt);
                const isOwner = account?.toLowerCase() === l.owner.toLowerCase();
                const isRenter = account?.toLowerCase() === l.renter.toLowerCase();
                const days = rentDays[String(l.id)] ?? "7";
                const extra = extendDays[String(l.id)] ?? "1";
                return (
                  <div className="card" key={String(l.id)}>
                    <b>#{String(l.id)}</b> · circuit <code>{shortAddr(l.circuit)}</code> #{String(l.tokenId)} ·{" "}
                    <b>{fmtOkb(l.pricePerDay)} OKB/day</b> · max {String(l.maxDays)} days · owner {shortAddr(l.owner)}
                    <br />
                    {rented ? (
                      <>Rented by {shortAddr(l.renter)} until {fmtDate(l.expiresAt)} {expired && "(expired — anyone can return it)"}</>
                    ) : l.active ? (
                      <>Available</>
                    ) : (
                      <>Closed</>
                    )}
                    <div className="row">
                      {l.active && !rented && (
                        <>
                          <input value={days} onChange={(e) => setRentDays({ ...rentDays, [String(l.id)]: e.target.value })} size={4} /> days
                          <button
                            disabled={busy || !account}
                            onClick={() =>
                              sendWrite(() =>
                                walletClient!.writeContract({
                                  address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "rent",
                                  args: [l.id, BigInt(days)], value: l.pricePerDay * BigInt(days), account: account!, chain,
                                }),
                              )
                            }
                          >
                            Rent ({days}d = {fmtOkb(l.pricePerDay * BigInt(days || "0"))} OKB)
                          </button>
                        </>
                      )}
                      {l.active && rented && isRenter && !expired && (
                        <>
                          <input value={extra} onChange={(e) => setExtendDays({ ...extendDays, [String(l.id)]: e.target.value })} size={4} /> extra days
                          <button
                            disabled={busy}
                            onClick={() =>
                              sendWrite(() =>
                                walletClient!.writeContract({
                                  address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "extend",
                                  args: [l.id, BigInt(extra)], value: l.pricePerDay * BigInt(extra), account: account!, chain,
                                }),
                              )
                            }
                          >
                            Extend
                          </button>
                          <button
                            disabled={busy}
                            onClick={() =>
                              sendWrite(() =>
                                walletClient!.writeContract({
                                  address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "endEarly",
                                  args: [l.id], account: account!, chain,
                                }),
                              )
                            }
                          >
                            End early (refund unused days)
                          </button>
                        </>
                      )}
                      {l.active && rented && expired && (
                        <button
                          disabled={busy || !account}
                          onClick={() =>
                            sendWrite(() =>
                              walletClient!.writeContract({
                                address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "returnCircuit",
                                args: [l.id], account: account!, chain,
                              }),
                            )
                          }
                        >
                          Return circuit to owner
                        </button>
                      )}
                      {l.active && !rented && isOwner && (
                        <button
                          disabled={busy}
                          onClick={() =>
                            sendWrite(() =>
                              walletClient!.writeContract({
                                address: tapeRentAddr as Address, abi: tapeRentAbi, functionName: "cancelListing",
                                args: [l.id], account: account!, chain,
                              }),
                            )
                          }
                        >
                          Cancel listing
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </>
          )}
        </section>
      )}

      <footer>
        <p className="note">
          ⚠️ TapeOut contracts are in test phase, upgradeable and unaudited; their owner can change fees. TapeRent is unaudited hackathon code.
          Built for the OKX X Layer TapeOut Accelerate hackathon. Fee: 2.5% of rent payments. No backend — all reads/writes go straight to X Layer RPC.
        </p>
      </footer>
    </div>
  );
}
