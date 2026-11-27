// Money and time formatting. All amounts are bigint ugnot (1 GNOT = 1e6).

export function formatGNOT(ugnot: bigint): string {
  const neg = ugnot < 0n;
  const v = neg ? -ugnot : ugnot;
  const whole = (v / 1_000_000n).toLocaleString("en-US");
  const frac = (v % 1_000_000n).toString().padStart(6, "0").replace(/0+$/, "");
  return `${neg ? "-" : ""}${whole}${frac ? "." + frac : ""} GNOT`;
}

export function formatInt(n: bigint): string {
  return n.toLocaleString("en-US");
}

// "1.25" GNOT -> 1250000n ugnot. Rejects more than 6 decimals.
export function parseGNOT(input: string): bigint {
  const s = input.trim();
  if (!/^\d+(\.\d{0,6})?$/.test(s)) throw new Error("enter a GNOT amount like 0.25 (max 6 decimals)");
  const [w, f = ""] = s.split(".");
  return BigInt(w) * 1_000_000n + BigInt(f.padEnd(6, "0"));
}

export function parseUnits(input: string): bigint {
  const s = input.trim();
  if (!/^\d+$/.test(s) || BigInt(s) <= 0n) throw new Error("enter a whole number of tokens");
  return BigInt(s);
}

export function formatCountdown(secs: number): string {
  if (secs <= 0) return "0s";
  const d = Math.floor(secs / 86400);
  const h = Math.floor((secs % 86400) / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = Math.floor(secs % 60);
  if (d) return `${d}d ${h}h`;
  if (h) return `${h}h ${m}m`;
  if (m) return `${m}m ${String(s).padStart(2, "0")}s`;
  return `${s}s`;
}

export function formatTime(unix: number): string {
  return new Date(unix * 1000).toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

export function shortAddr(a: string): string {
  return a.length > 14 ? `${a.slice(0, 8)}…${a.slice(-4)}` : a;
}
