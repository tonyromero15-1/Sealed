import { RPC_URL } from "../config";

// Minimal tm2 JSON-RPC client: abci_query against the Onyx RPC (CORS is open).

function b64encode(s: string): string {
  const bytes = new TextEncoder().encode(s);
  let bin = "";
  bytes.forEach((b) => (bin += String.fromCharCode(b)));
  return btoa(bin);
}

function b64decode(s: string): string {
  const bin = atob(s);
  const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

export class QueryError extends Error {}

export async function abciQuery(path: string, data: string): Promise<string> {
  const res = await fetch(RPC_URL.replace(/:443$/, ""), {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "abci_query", params: { path, data: b64encode(data) } }),
  });
  if (!res.ok) throw new QueryError(`RPC ${res.status}`);
  const json = await res.json();
  if (json.error) throw new QueryError(json.error.message ?? "RPC error");
  const base = json.result?.response?.ResponseBase;
  if (base?.Error) {
    const log: string = base.Log ?? "";
    // Gno puts the readable reason after the last " - " of the trace.
    const m = log.match(/ - ([^\n]+)\n/g);
    throw new QueryError(m ? m[m.length - 1].replace(/^ - /, "").trim() : log.slice(0, 200));
  }
  return base?.Data ? b64decode(base.Data) : "";
}

// qeval returns a Gno value literal, e.g. `(42 int64)` or `("abc" string)`.
export function qeval(pkgPath: string, expr: string): Promise<string> {
  return abciQuery("vm/qeval", `${pkgPath}.${expr}`);
}

export function qrender(pkgPath: string, path = ""): Promise<string> {
  return abciQuery("vm/qrender", `${pkgPath}:${path}`);
}

// Parses `("..." string)` into the Go string it holds.
export function parseString(lit: string): string {
  const m = lit.trim().match(/^\((".*") string\)$/s);
  if (!m) throw new QueryError("unexpected value: " + lit.slice(0, 120));
  return JSON.parse(m[1]);
}

// Parses `(123 int)` / `(123 int64)` / `(true bool)`.
export function parseScalar(lit: string): string {
  const m = lit.trim().match(/^\(([^ ]+) [\w.]+\)$/);
  if (!m) throw new QueryError("unexpected value: " + lit.slice(0, 120));
  return m[1];
}
