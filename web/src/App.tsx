import { useEffect, useState } from "react";
import { AuctionList } from "./components/AuctionList";
import { AuctionPage } from "./components/AuctionPage";
import { Notice } from "./components/ui";
import { CHAIN_ID } from "./config";
import { connect, hasAdena, onAccountChange } from "./lib/adena";
import { shortAddr } from "./lib/format";
import { useRoute } from "./hooks";

export default function App() {
  const { auctionId, go } = useRoute();
  const [address, setAddress] = useState<string | null>(null);
  const [walletErr, setWalletErr] = useState<string | null>(null);
  const [connecting, setConnecting] = useState(false);

  const doConnect = async () => {
    setWalletErr(null);
    if (!hasAdena()) {
      setWalletErr("Adena wallet not found.");
      window.open("https://adena.app/", "_blank", "noopener");
      return;
    }
    setConnecting(true);
    try {
      setAddress(await connect());
    } catch (e) {
      setWalletErr(String((e as Error)?.message ?? e));
    } finally {
      setConnecting(false);
    }
  };

  useEffect(() => {
    onAccountChange((a) => setAddress(a || null));
  }, []);

  return (
    <div className="mx-auto min-h-screen max-w-4xl px-4 pb-20 sm:px-6">
      <header className="flex items-center justify-between py-6">
        <button onClick={() => go(null)} className="flex items-center gap-2 text-lg font-bold tracking-[0.2em]">
          <span className="grid h-8 w-8 place-items-center rounded-full bg-seal text-ink-950">◉</span>
          SEALED
        </button>
        <div className="flex items-center gap-3">
          <span className="hidden rounded-full border border-ink-700 px-2.5 py-1 text-xs text-ink-300 sm:inline">{CHAIN_ID}</span>
          {address ? (
            <span className="rounded-xl border border-ink-700 px-3 py-2 font-mono text-xs">{shortAddr(address)}</span>
          ) : (
            <button className="btn-primary" onClick={doConnect} disabled={connecting}>
              {connecting ? "Connecting…" : "Connect Adena"}
            </button>
          )}
        </div>
      </header>
      {walletErr && <div className="mb-4"><Notice tone="error">{walletErr}</Notice></div>}
      <main>
        {auctionId ? (
          <AuctionPage id={auctionId} address={address} onBack={() => go(null)} onConnect={doConnect} />
        ) : (
          <AuctionList onOpen={(id) => go(id)} />
        )}
      </main>
      <footer className="mt-16 text-center text-xs text-ink-500">
        Sealed-bid, uniform-price auctions on Gno.land · every winner pays the same price
      </footer>
    </div>
  );
}
