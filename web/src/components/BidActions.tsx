import { useMemo, useState } from "react";
import { MIN_DEPOSIT, FORFEIT_PERCENT, CHAIN_ID, REALM_PATH } from "../config";
import { callSealed } from "../lib/adena";
import { makeCommitment, randomSalt } from "../lib/commitment";
import { formatGNOT, formatInt, parseGNOT, parseUnits } from "../lib/format";
import type { Auction, Bid, Phase } from "../lib/sealed";
import { backupFileName, downloadBackup, loadBid, parseBackup, saveBid, type SavedBid } from "../lib/vault";
import { Mono, Notice } from "./ui";

interface Props {
  auction: Auction;
  phase: Phase;
  address: string | null;
  myBid: Bid | null;
  onConnect: () => void;
  onDone: (msg: string) => void;
}

// What the connected account can do right now, by phase.
export function BidActions(p: Props) {
  if (!p.address) {
    return (
      <div className="card p-5">
        <p className="mb-3 text-sm text-ink-300">Connect your Adena wallet to bid on this auction.</p>
        <button className="btn-primary" onClick={p.onConnect}>Connect Adena</button>
      </div>
    );
  }
  switch (p.phase) {
    case "Commit":
      return p.myBid ? <Sealed bid={p.myBid} /> : <SealForm {...p} address={p.address} />;
    case "Reveal":
      return <RevealPanel {...p} address={p.address} />;
    case "Ready to settle":
      return <SettlePanel {...p} address={p.address} />;
    case "Settled":
      return <ClaimPanel {...p} address={p.address} />;
  }
}

function useTx(onDone: (m: string) => void) {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const run = async (label: string, f: () => Promise<string>) => {
    setBusy(true);
    setErr(null);
    try {
      const hash = await f();
      onDone(`${label} sent${hash ? ` · tx ${hash.slice(0, 12)}…` : ""}`);
    } catch (e) {
      setErr(String((e as Error)?.message ?? e));
    } finally {
      setBusy(false);
    }
  };
  return { busy, err, run };
}

function Sealed({ bid }: { bid: Bid }) {
  return (
    <div className="card p-5">
      <div className="text-sm font-semibold text-seal">🔒 Your bid is sealed</div>
      <p className="mt-1 text-sm text-ink-300">
        Deposit {formatGNOT(bid.deposit)}. Come back when the reveal phase opens and press Reveal. Keep your backup file.
      </p>
      <div className="mt-3"><Mono>commitment {bid.commitment}</Mono></div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Seal my bid

function SealForm({ auction, address, onDone }: Props & { address: string }) {
  const [price, setPrice] = useState("");
  const [amount, setAmount] = useState("");
  const [hide, setHide] = useState(false);
  const [extra, setExtra] = useState("");
  const [pending, setPending] = useState<SavedBid | null>(null);
  const [downloaded, setDownloaded] = useState(false);
  const [ack, setAck] = useState(false);
  const { busy, err, run } = useTx(onDone);

  const calc = useMemo(() => {
    try {
      const pr = parseGNOT(price);
      const am = parseUnits(amount);
      if (pr <= 0n) throw new Error("price must be above 0");
      const cost = pr * am;
      const pad = hide && extra ? parseGNOT(extra) : 0n;
      const deposit = cost + pad;
      const warn =
        pr < auction.reservePrice
          ? `Below the reserve price (${formatGNOT(auction.reservePrice)}): this bid can't win.`
          : deposit < MIN_DEPOSIT
            ? `The minimum deposit is ${formatGNOT(MIN_DEPOSIT)}.`
            : null;
      return { pr, am, cost, deposit, warn, ok: deposit >= MIN_DEPOSIT };
    } catch (e) {
      return { error: (e as Error).message };
    }
  }, [price, amount, hide, extra, auction.reservePrice]);

  const prepare = async () => {
    if (!("ok" in calc) || !calc.ok) return;
    const salt = randomSalt();
    const commitment = await makeCommitment(address, calc.pr, calc.am, salt);
    const b: SavedBid = {
      app: "SEALED",
      version: 1,
      chainId: CHAIN_ID,
      realm: REALM_PATH,
      auctionId: auction.id,
      bidder: address,
      price: calc.pr.toString(),
      amount: calc.am.toString(),
      salt,
      deposit: calc.deposit.toString(),
      commitment,
      createdAt: new Date().toISOString(),
    };
    saveBid(b);
    downloadBackup(b);
    setDownloaded(true);
    setAck(false);
    setPending(b);
  };

  const send = () =>
    pending &&
    run("Sealed bid", () => callSealed(address, "Commit", [String(auction.id), pending.commitment], BigInt(pending.deposit)));

  return (
    <div className="card p-5">
      <h3 className="text-base font-semibold">Seal my bid</h3>
      <p className="mt-1 text-sm text-ink-300">
        Nobody sees your price or amount until you reveal. Everyone who wins pays the same clearing price, so bid what
        the tokens are worth to you.
      </p>

      {!pending ? (
        <div className="mt-4 grid gap-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <label>
              <span className="label">Price (GNOT per {auction.symbol})</span>
              <input className="input" inputMode="decimal" placeholder={`≥ ${formatGNOT(auction.reservePrice)}`} value={price} onChange={(e) => setPrice(e.target.value)} />
            </label>
            <label>
              <span className="label">Amount ({auction.symbol})</span>
              <input className="input" inputMode="numeric" placeholder={`up to ${formatInt(auction.supply)}`} value={amount} onChange={(e) => setAmount(e.target.value)} />
            </label>
          </div>

          <label className="flex cursor-pointer items-start gap-3 text-sm">
            <input type="checkbox" className="mt-1 accent-[#f5a524]" checked={hide} onChange={(e) => setHide(e.target.checked)} />
            <span>
              <span className="font-medium">Hide my size</span>
              <span className="block text-ink-500">Deposits are public. Add extra so yours doesn't reveal your bid. The extra is refunded at Claim.</span>
            </span>
          </label>
          {hide && (
            <label>
              <span className="label">Extra deposit (GNOT)</span>
              <input className="input" inputMode="decimal" placeholder="e.g. 5" value={extra} onChange={(e) => setExtra(e.target.value)} />
            </label>
          )}

          {"error" in calc ? (
            price || amount ? <Notice tone="error">{calc.error}</Notice> : null
          ) : (
            <div className="rounded-xl border border-ink-700 bg-ink-950 p-4 text-sm">
              <div className="flex justify-between"><span className="text-ink-300">Bid value</span><span>{formatGNOT(calc.cost)}</span></div>
              {calc.deposit !== calc.cost && (
                <div className="flex justify-between"><span className="text-ink-300">Extra (refunded)</span><span>{formatGNOT(calc.deposit - calc.cost)}</span></div>
              )}
              <div className="mt-2 flex justify-between border-t border-ink-700 pt-2 font-semibold"><span>Deposit sent now</span><span className="text-seal">{formatGNOT(calc.deposit)}</span></div>
              {calc.warn && <div className="mt-3"><Notice tone="warn">{calc.warn}</Notice></div>}
            </div>
          )}

          <button className="btn-primary" disabled={!("ok" in calc) || !calc.ok} onClick={prepare}>
            🔒 Seal my bid
          </button>
        </div>
      ) : (
        <div className="mt-4 grid gap-4">
          <Notice tone="warn">
            <div className="text-base font-bold">⚠️ Keep your backup file safe.</div>
            <div className="mt-1">
              Your bid's secret salt exists only on this device and in <b>{backupFileName(pending)}</b>.
              <b> Lose it and you can't reveal: you lose {FORFEIT_PERCENT}% of your deposit</b> ({formatGNOT((BigInt(pending.deposit) * BigInt(FORFEIT_PERCENT)) / 100n)}).
            </div>
          </Notice>
          <div className="flex flex-wrap gap-3">
            <button className="btn-ghost" onClick={() => (downloadBackup(pending), setDownloaded(true))}>⬇ Download backup again</button>
            <button className="btn-ghost" onClick={() => setPending(null)} disabled={busy}>Edit bid</button>
          </div>
          <label className="flex cursor-pointer items-start gap-3 text-sm">
            <input type="checkbox" className="mt-1 accent-[#f5a524]" checked={ack} onChange={(e) => setAck(e.target.checked)} disabled={!downloaded} />
            <span>I saved the backup file. I understand I need it (or this browser) to reveal.</span>
          </label>
          <button className="btn-primary" disabled={!ack || busy} onClick={send}>
            {busy ? "Waiting for Adena…" : `Send sealed bid with ${formatGNOT(BigInt(pending.deposit))}`}
          </button>
          {err && <Notice tone="error">{err}</Notice>}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Reveal my bid

function RevealPanel({ auction, address, myBid, onDone }: Props & { address: string }) {
  const [fromFile, setFromFile] = useState<SavedBid | null>(null);
  const [fileErr, setFileErr] = useState<string | null>(null);
  const [check, setCheck] = useState<string | null>(null);
  const { busy, err, run } = useTx(onDone);

  if (!myBid) return <Notice>This account has no sealed bid in this auction. Reveal is open to bidders only.</Notice>;
  if (myBid.revealed) {
    return (
      <Notice tone="ok">
        🔓 Revealed: {formatGNOT(myBid.price)} × {formatInt(myBid.amount)} {auction.symbol}. Results come after the
        reveal window closes.
      </Notice>
    );
  }

  const saved = fromFile ?? loadBid(auction.id, address);
  const reveal = async () => {
    if (!saved) return;
    // Check locally first: a wrong salt would only waste a transaction.
    const c = await makeCommitment(address, BigInt(saved.price), BigInt(saved.amount), saved.salt);
    if (c !== myBid.commitment) {
      setCheck("This backup does not match your sealed bid on chain (different auction, account or salt).");
      return;
    }
    setCheck(null);
    run("Reveal", () => callSealed(address, "Reveal", [String(auction.id), saved.price, saved.amount, saved.salt]));
  };

  return (
    <div className="card p-5">
      <h3 className="text-base font-semibold">Reveal my bid</h3>
      <p className="mt-1 text-sm text-ink-300">
        Open your sealed bid before the window closes, or {FORFEIT_PERCENT}% of your {formatGNOT(myBid.deposit)} deposit goes to the winners.
      </p>
      {saved ? (
        <div className="mt-4 rounded-xl border border-ink-700 bg-ink-950 p-4 text-sm">
          <div className="flex justify-between"><span className="text-ink-300">Price</span><span>{formatGNOT(BigInt(saved.price))} per {auction.symbol}</span></div>
          <div className="flex justify-between"><span className="text-ink-300">Amount</span><span>{formatInt(BigInt(saved.amount))} {auction.symbol}</span></div>
          <div className="mt-2"><Mono>salt {saved.salt}</Mono></div>
        </div>
      ) : (
        <div className="mt-4">
          <Notice tone="warn">No saved bid in this browser. Load your backup file:</Notice>
        </div>
      )}
      <label className="mt-3 block text-sm text-ink-300">
        <span className="label">{saved ? "Or load a different backup file" : "Backup file"}</span>
        <input
          type="file"
          accept="application/json,.json"
          className="block w-full text-sm file:mr-3 file:rounded-lg file:border-0 file:bg-ink-700 file:px-3 file:py-2 file:text-ink-100"
          onChange={async (e) => {
            const f = e.target.files?.[0];
            if (!f) return;
            try {
              const b = parseBackup(await f.text());
              if (b.auctionId !== auction.id || b.bidder !== address) throw new Error("this backup is for another auction or account");
              setFromFile(b);
              setFileErr(null);
            } catch (x) {
              setFileErr((x as Error).message);
            }
          }}
        />
      </label>
      {fileErr && <div className="mt-2"><Notice tone="error">{fileErr}</Notice></div>}
      {check && <div className="mt-2"><Notice tone="error">{check}</Notice></div>}
      <button className="btn-primary mt-4" disabled={!saved || busy} onClick={reveal}>
        {busy ? "Waiting for Adena…" : "🔓 Reveal my bid"}
      </button>
      {err && <div className="mt-3"><Notice tone="error">{err}</Notice></div>}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Settle (anyone) and Claim

function SettlePanel({ auction, address, onDone }: Props & { address: string }) {
  const { busy, err, run } = useTx(onDone);
  return (
    <div className="card p-5">
      <h3 className="text-base font-semibold">Reveal window closed</h3>
      <p className="mt-1 text-sm text-ink-300">Anyone can settle. Settling moves no funds; it fixes the clearing price and every allocation.</p>
      <button className="btn-primary mt-4" disabled={busy} onClick={() => run("Settle", () => callSealed(address, "Settle", [String(auction.id)]))}>
        {busy ? "Waiting for Adena…" : "Settle auction"}
      </button>
      {err && <div className="mt-3"><Notice tone="error">{err}</Notice></div>}
    </div>
  );
}

function ClaimPanel({ auction, address, myBid, onDone }: Props & { address: string }) {
  const { busy, err, run } = useTx(onDone);
  const isSeller = address === auction.seller;
  const bidOwed = myBid && !myBid.claimed ? myBid.refund + myBid.forfeitShare : 0n;
  const tokensOwed = myBid && !myBid.claimed ? myBid.filled : 0n;
  const sellerOwed = isSeller && !auction.sellerClaimed;
  const nothing = !sellerOwed && !(myBid && !myBid.claimed);

  if (nothing) {
    return <Notice tone={myBid || isSeller ? "ok" : "info"}>{myBid || isSeller ? "✓ Everything you were owed has been claimed." : "This account has nothing to claim here."}</Notice>;
  }
  return (
    <div className="card p-5">
      <h3 className="text-base font-semibold">Claim</h3>
      <div className="mt-3 rounded-xl border border-ink-700 bg-ink-950 p-4 text-sm">
        {myBid && !myBid.claimed && (
          <>
            <div className="flex justify-between"><span className="text-ink-300">Tokens won</span><span>{formatInt(tokensOwed)} {auction.symbol}</span></div>
            <div className="flex justify-between"><span className="text-ink-300">Refund</span><span>{formatGNOT(myBid.refund)}</span></div>
            {myBid.forfeitShare > 0n && <div className="flex justify-between"><span className="text-ink-300">Forfeit share</span><span className="text-seal">+{formatGNOT(myBid.forfeitShare)}</span></div>}
            <div className="mt-2 flex justify-between border-t border-ink-700 pt-2 font-semibold"><span>You receive</span><span>{formatGNOT(bidOwed)}</span></div>
          </>
        )}
        {sellerOwed && (
          <>
            <div className="flex justify-between"><span className="text-ink-300">Sale proceeds</span><span>{formatGNOT(auction.raised)}</span></div>
            <div className="flex justify-between"><span className="text-ink-300">Unsold tokens back</span><span>{formatInt(auction.supply - auction.sold)} {auction.symbol}</span></div>
          </>
        )}
      </div>
      <button className="btn-primary mt-4" disabled={busy} onClick={() => run("Claim", () => callSealed(address, "Claim", [String(auction.id)]))}>
        {busy ? "Waiting for Adena…" : "Claim"}
      </button>
      {err && <div className="mt-3"><Notice tone="error">{err}</Notice></div>}
    </div>
  );
}
