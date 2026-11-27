import { CHAIN_ID, REALM_PATH } from "../config";

// A sealed bid's secret half. Without the salt the bid can never be
// revealed, and the bidder loses 10% of the deposit. So we keep it in
// localStorage AND make the user download a backup file before sending.

export interface SavedBid {
  app: "SEALED";
  version: 1;
  chainId: string;
  realm: string;
  auctionId: number;
  bidder: string;
  price: string; // ugnot per token unit, base 10
  amount: string; // token units, base 10
  salt: string;
  deposit: string; // ugnot actually sent
  commitment: string;
  createdAt: string; // ISO time
}

const key = (auctionId: number, bidder: string) => `sealed:bid:${CHAIN_ID}:${REALM_PATH}:${auctionId}:${bidder}`;

export function saveBid(b: SavedBid) {
  try {
    localStorage.setItem(key(b.auctionId, b.bidder), JSON.stringify(b));
  } catch {
    // Private mode etc.: the downloaded backup is then the only copy.
  }
}

export function loadBid(auctionId: number, bidder: string): SavedBid | null {
  try {
    const raw = localStorage.getItem(key(auctionId, bidder));
    return raw ? parseBackup(raw) : null;
  } catch {
    return null;
  }
}

export function parseBackup(text: string): SavedBid {
  const b = JSON.parse(text);
  if (b?.app !== "SEALED" || b.version !== 1) throw new Error("not a SEALED bid backup file");
  for (const f of ["realm", "bidder", "price", "amount", "salt", "commitment"]) {
    if (typeof b[f] !== "string" || !b[f]) throw new Error(`backup is missing "${f}"`);
  }
  if (!Number.isInteger(b.auctionId)) throw new Error("backup is missing the auction id");
  return b as SavedBid;
}

export function backupFileName(b: SavedBid): string {
  return `sealed-bid-auction${b.auctionId}-${b.bidder.slice(0, 10)}.json`;
}

export function downloadBackup(b: SavedBid) {
  const blob = new Blob([JSON.stringify(b, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = backupFileName(b);
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
