import { useCallback, useState } from "react";
import { GNOWEB_URL, REALM_PATH } from "../config";
import { useLoader, useNow } from "../hooks";
import { formatCountdown, formatGNOT, formatInt, formatTime, shortAddr } from "../lib/format";
import { getAuction, getBid, listBids, phaseAt, type Auction, type Bid } from "../lib/sealed";
import { BidActions } from "./BidActions";
import { Mono, Notice, PhaseBadge, Stat } from "./ui";

export function AuctionPage({ id, address, onBack, onConnect }: { id: number; address: string | null; onBack: () => void; onConnect: () => void }) {
  const now = useNow();
  const [flash, setFlash] = useState<string | null>(null);
  const load = useCallback(async () => {
    const a = await getAuction(id);
    const [mine, bids] = await Promise.all([
      address ? getBid(id, address) : Promise.resolve(null),
      a.settled ? listBids(id, a.sealedBids) : Promise.resolve([] as Bid[]),
    ]);
    return { a, mine, bids };
  }, [id, address]);
  const { data, error, refresh } = useLoader(load, [load], 8_000);

  if (error) return <Notice tone="error">Could not load auction #{id}: {error}</Notice>;
  if (!data) return <div className="text-ink-500">Loading auction #{id} from Onyx…</div>;
  const { a, mine, bids } = data;
  const phase = phaseAt(a, now);
  const end = phase === "Commit" ? a.commitEnd : phase === "Reveal" ? a.revealEnd : 0;

  return (
    <section className="grid gap-6">
      <button onClick={onBack} className="w-fit text-sm text-ink-300 hover:text-seal">← All auctions</button>

      <div className="card p-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <div className="font-mono text-sm text-ink-500">Auction #{a.id}</div>
            <h1 className="text-2xl font-bold">{formatInt(a.supply)} {a.symbol}</h1>
          </div>
          <div className="text-right">
            <PhaseBadge phase={phase} />
            {end > 0 && <div className="mt-2 text-2xl font-semibold tabular-nums text-seal">{formatCountdown(end - now)}</div>}
          </div>
        </div>
        <Timeline a={a} now={now} />
        <div className="mt-6 grid grid-cols-2 gap-5 sm:grid-cols-4">
          <Stat label="Sealed bids" value={`🔒 ${a.sealedBids}`} hint={phase === "Commit" ? "contents hidden" : `${a.revealed} revealed`} />
          <Stat label="Reserve" value={formatGNOT(a.reservePrice)} hint={`per ${a.symbol}`} />
          <Stat label="Commit ends" value={formatTime(a.commitEnd)} />
          <Stat label="Reveal ends" value={formatTime(a.revealEnd)} />
        </div>
        <div className="mt-5 grid gap-1">
          <Mono>token {a.token}</Mono>
          <Mono>seller {a.seller}</Mono>
        </div>
      </div>

      {flash && <Notice tone="ok">{flash} · it shows here once it is in a block.</Notice>}
      <BidActions
        auction={a}
        phase={phase}
        address={address}
        myBid={mine}
        onConnect={onConnect}
        onDone={(m) => {
          setFlash(m);
          setTimeout(refresh, 3000);
        }}
      />

      {a.settled && <Results a={a} bids={bids} me={address} />}

      <a className="text-xs text-ink-500 hover:text-seal" href={`${GNOWEB_URL}/${REALM_PATH.replace(/^gno\.land\//, "")}:auction/${a.id}`} target="_blank" rel="noreferrer">
        View this auction's realm page on gnoweb ↗
      </a>
    </section>
  );
}

function Timeline({ a, now }: { a: Auction; now: number }) {
  const total = a.revealEnd - a.createdAt;
  const pct = (t: number) => Math.min(100, Math.max(0, ((t - a.createdAt) / total) * 100));
  return (
    <div className="mt-6">
      <div className="relative h-2 rounded-full bg-ink-800">
        <div className="absolute inset-y-0 left-0 rounded-full bg-seal/70" style={{ width: `${a.settled ? 100 : pct(now)}%` }} />
        <div className="absolute inset-y-[-3px] w-0.5 bg-ink-100" style={{ left: `${pct(a.commitEnd)}%` }} />
      </div>
      <div className="mt-2 flex justify-between text-xs text-ink-500">
        <span>Commit</span>
        <span>Reveal</span>
        <span>Settle</span>
      </div>
    </div>
  );
}

function Results({ a, bids, me }: { a: Auction; bids: Bid[]; me: string | null }) {
  const sorted = [...bids].sort((x, y) => (x.revealed !== y.revealed ? (x.revealed ? -1 : 1) : x.price === y.price ? 0 : x.price > y.price ? -1 : 1));
  return (
    <div className="card p-6">
      <h2 className="text-lg font-semibold">✅ Results</h2>
      <div className="mt-4 grid grid-cols-2 gap-5 sm:grid-cols-4">
        <Stat label="Clearing price" value={<span className="text-seal">{formatGNOT(a.clearingPrice)}</span>} hint={`every winner pays this per ${a.symbol}`} />
        <Stat label="Sold" value={`${formatInt(a.sold)} / ${formatInt(a.supply)}`} />
        <Stat label="Total raised" value={formatGNOT(a.raised)} hint={a.sellerClaimed ? "seller claimed ✓" : "to the seller"} />
        <Stat label="Forfeits" value={formatGNOT(a.forfeits)} hint={a.burned > 0n ? `${formatGNOT(a.burned)} burned` : "shared by winners"} />
      </div>
      <div className="mt-6 overflow-x-auto">
        <table className="w-full min-w-[640px] text-sm">
          <thead className="text-left text-xs uppercase tracking-wide text-ink-500">
            <tr>
              <th className="py-2">Bidder</th><th className="text-right">Bid</th><th className="text-right">Wanted</th><th className="text-right">Won</th>
              <th className="text-right">Pays</th><th className="text-right">Refund</th><th className="text-right">Forfeit share</th><th className="pl-4">Result</th><th>Claimed</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-ink-800">
            {sorted.map((b) => (
              <tr key={b.bidder} className={b.bidder === me ? "bg-seal-dim/40" : ""}>
                <td className="py-2 font-mono text-xs">{shortAddr(b.bidder)}{b.bidder === me && <span className="ml-1 text-seal">you</span>}</td>
                <td className="text-right">{b.revealed ? formatGNOT(b.price) : "sealed"}</td>
                <td className="text-right">{b.revealed ? formatInt(b.amount) : "—"}</td>
                <td className="text-right">{formatInt(b.filled)}</td>
                <td className="text-right">{formatGNOT(b.cost)}</td>
                <td className="text-right">{formatGNOT(b.refund)}</td>
                <td className="text-right text-seal">{b.forfeitShare > 0n ? `+${formatGNOT(b.forfeitShare)}` : "—"}</td>
                <td className="pl-4">{b.status}</td>
                <td>{b.claimed ? "✓" : "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
