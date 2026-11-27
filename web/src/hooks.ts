import { useCallback, useEffect, useState } from "react";

// Wall-clock seconds, ticking once a second (countdowns are computed
// client-side from the auction's absolute end times).
export function useNow(): number {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));
  useEffect(() => {
    const t = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000);
    return () => clearInterval(t);
  }, []);
  return now;
}

// Tiny hash router: "#/" (list) and "#/auction/<id>".
export function useRoute(): { auctionId: number | null; go: (id: number | null) => void } {
  const parse = () => {
    const m = window.location.hash.match(/^#\/auction\/(\d+)/);
    return m ? Number(m[1]) : null;
  };
  const [auctionId, setId] = useState(parse);
  useEffect(() => {
    const on = () => setId(parse());
    window.addEventListener("hashchange", on);
    return () => window.removeEventListener("hashchange", on);
  }, []);
  const go = useCallback((id: number | null) => {
    window.location.hash = id ? `#/auction/${id}` : "#/";
  }, []);
  return { auctionId, go };
}

// Loads data with a refresh function and a polling interval.
export function useLoader<T>(load: () => Promise<T>, deps: unknown[], pollMs = 10_000) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [tick, setTick] = useState(0);
  const refresh = useCallback(() => setTick((t) => t + 1), []);
  useEffect(() => {
    let live = true;
    load()
      .then((d) => live && (setData(d), setError(null)))
      .catch((e) => live && setError(String(e?.message ?? e)));
    const t = setInterval(() => setTick((x) => x + 1), pollMs);
    return () => {
      live = false;
      clearInterval(t);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);
  return { data, error, refresh };
}
