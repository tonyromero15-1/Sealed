import { useNow, useLoader } from "../hooks";
import { formatCountdown, formatGNOT, formatInt } from "../lib/format";
import { listAuctions, phaseAt } from "../lib/sealed";
import { Notice, PhaseBadge } from "./ui";

export function AuctionList({ onOpen }: { onOpen: (id: number) => void }) {
  const now = useNow();
  const { data, error } = useLoader(listAuctions, [], 15_000);

  return (
    <section>
      <div className="mb-8">
        <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">Sealed-bid token launches.</h1>
        <p className="mt-2 text-lg text-ink-300">Speed becomes worthless.</p>
        <ol className="mt-6 grid gap-3 sm:grid-cols-3">
          {[
            ["Commit", "Post a hash of your bid plus a GNOT deposit. Nobody can see any bid."],
            ["Reveal", "Open your bid. The realm checks it against your hash."],
            ["Settle", "Highest bids fill first. Every winner pays the same clearing price."],
          ].map(([t, d], i) => (
            <li key={t} className="card p-4">
              <div className="text-xs font-semibold text-seal">{i + 1}. {t}</div>
              <div className="mt-1 text-sm text-ink-300">{d}</div>
            </li>
          ))}
        </ol>
      </div>

      <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-ink-300">Auctions</h2>
      {error && <Notice tone="error">Could not reach the chain: {error}</Notice>}
      {!data && !error && <div className="text-ink-500">Loading from Onyx…</div>}
      {data && data.length === 0 && <Notice>No auctions yet.</Notice>}
      <div className="grid gap-3">
        {data?.map((a) => {
          const phase = phaseAt(a, now);
          const end = phase === "Commit" ? a.commitEnd : phase === "Reveal" ? a.revealEnd : 0;
          return (
            <button key={a.id} onClick={() => onOpen(a.id)} className="card flex flex-wrap items-center gap-x-6 gap-y-2 p-4 text-left transition hover:border-seal/60">
              <div className="w-14 font-mono text-ink-500">#{a.id}</div>
              <div className="min-w-[8rem] flex-1">
                <div className="font-semibold">{formatInt(a.supply)} {a.symbol}</div>
                <div className="text-xs text-ink-500">reserve {formatGNOT(a.reservePrice)}</div>
              </div>
              <PhaseBadge phase={phase} />
              <div className="w-24 text-sm tabular-nums text-ink-300">{end ? formatCountdown(end - now) + " left" : "—"}</div>
              <div className="w-28 text-right text-sm text-ink-300">🔒 {a.sealedBids} sealed</div>
            </button>
          );
        })}
      </div>
    </section>
  );
}
