import { REALM_PATH } from "../config";
import { parseFirstString, parseScalar, parseString, qeval } from "./rpc";

// Reads SEALED v1 state through vm/qeval.
//
// v1 has no exported "get auction as data" function, so these queries call
// the realm's own internals (mustGetAuction, getBid, outcomeOf, formatInt,
// check, tokenSymbol). qeval is read-only and runs in the realm's package
// scope, so this works on the deployed v1 without a redeploy. v2 should add
// exported getters (see web/README.md) so the page stops depending on
// private names.

export type Phase = "Commit" | "Reveal" | "Ready to settle" | "Settled";

export interface Auction {
  id: number;
  seller: string;
  token: string;
  symbol: string;
  supply: bigint;
  reservePrice: bigint; // ugnot per token unit
  commitEnd: number; // unix seconds
  revealEnd: number;
  createdAt: number;
  sealedBids: number;
  revealed: number;
  settled: boolean;
  clearingPrice: bigint;
  sold: bigint;
  raised: bigint;
  forfeits: bigint;
  burned: bigint;
  sellerClaimed: boolean;
}

export interface Bid {
  bidder: string;
  commitment: string;
  deposit: bigint;
  revealed: boolean;
  price: bigint;
  amount: bigint;
  claimed: boolean;
  // outcome (meaningful once settled)
  filled: bigint;
  cost: bigint;
  refund: bigint;
  forfeitShare: bigint;
  status: string;
}

const ADDR_RE = /^g1[02-9ac-hj-np-z]{38}$/;

function assertId(id: number) {
  if (!Number.isInteger(id) || id < 1) throw new Error("bad auction id");
}

function assertAddr(addr: string) {
  if (!ADDR_RE.test(addr)) throw new Error("bad address");
}

// formatInt adds thousands separators; strip them.
const num = (s: string) => BigInt(s.replace(/,/g, ""));
const flag = (s: string) => s === "✓";

// Joins expressions that each return a string into one query, "|"-separated
// (no field can contain "|": addresses, hex, numbers, token keys, statuses).
async function evalFields(exprs: string[]): Promise<string[]> {
  const lit = await qeval(REALM_PATH, exprs.join(' + "|" + '));
  return parseString(lit).split("|");
}

export async function auctionCount(): Promise<number> {
  return Number(parseScalar(await qeval(REALM_PATH, "auctions.Size()")));
}

export async function getAuction(id: number): Promise<Auction> {
  assertId(id);
  const a = `mustGetAuction(${id})`;
  const f = await evalFields([
    `${a}.Seller.String()`,
    `${a}.Token`,
    `tokenSymbol(${a}.Token)`,
    `formatInt(${a}.Supply)`,
    `formatInt(${a}.ReservePrice)`,
    `formatInt(${a}.CommitEnd)`,
    `formatInt(${a}.RevealEnd)`,
    `formatInt(${a}.CreatedAt)`,
    `formatInt(int64(${a}.bids.Size()))`,
    `formatInt(int64(${a}.numRevealed))`,
    `check(${a}.settled)`,
    `formatInt(${a}.clearingPrice)`,
    `formatInt(${a}.sold)`,
    `formatInt(${a}.raised)`,
    `formatInt(${a}.forfeits)`,
    `formatInt(${a}.burned)`,
    `check(${a}.sellerClaimed)`,
  ]);
  return {
    id,
    seller: f[0],
    token: f[1],
    symbol: f[2],
    supply: num(f[3]),
    reservePrice: num(f[4]),
    commitEnd: Number(num(f[5])),
    revealEnd: Number(num(f[6])),
    createdAt: Number(num(f[7])),
    sealedBids: Number(num(f[8])),
    revealed: Number(num(f[9])),
    settled: flag(f[10]),
    clearingPrice: num(f[11]),
    sold: num(f[12]),
    raised: num(f[13]),
    forfeits: num(f[14]),
    burned: num(f[15]),
    sellerClaimed: flag(f[16]),
  };
}

export async function listAuctions(): Promise<Auction[]> {
  const n = await auctionCount();
  const ids = Array.from({ length: n }, (_, i) => n - i); // newest first
  return Promise.all(ids.map(getAuction));
}

export async function getBid(id: number, bidder: string): Promise<Bid | null> {
  assertId(id);
  assertAddr(bidder);
  const b = `mustGetAuction(${id}).getBid("${bidder}")`;
  const exists = parseScalar(await qeval(REALM_PATH, `${b} != nil`));
  if (exists !== "true") return null;
  const o = `mustGetAuction(${id}).outcomeOf(${b})`;
  const f = await evalFields([
    `${b}.Commitment`,
    `formatInt(${b}.Deposit)`,
    `check(${b}.Revealed)`,
    `formatInt(${b}.Price)`,
    `formatInt(${b}.Amount)`,
    `check(${b}.Claimed)`,
    `formatInt(${o}.Filled)`,
    `formatInt(${o}.Cost)`,
    `formatInt(${o}.Refund)`,
    `formatInt(${o}.ForfeitShare)`,
    `${o}.Status`,
  ]);
  return {
    bidder,
    commitment: f[0],
    deposit: num(f[1]),
    revealed: flag(f[2]),
    price: num(f[3]),
    amount: num(f[4]),
    claimed: flag(f[5]),
    filled: num(f[6]),
    cost: num(f[7]),
    refund: num(f[8]),
    forfeitShare: num(f[9]),
    status: f[10],
  };
}

export async function listBids(id: number, count: number): Promise<Bid[]> {
  assertId(id);
  const keys = await Promise.all(
    Array.from({ length: count }, (_, i) =>
      // GetByIndex returns (key, value); the key is the bidder address.
      qeval(REALM_PATH, `mustGetAuction(${id}).bids.GetByIndex(${i})`).then(parseFirstString),
    ),
  );
  const bids = await Promise.all(keys.map((k) => getBid(id, k)));
  return bids.filter((b): b is Bid => b !== null);
}

// The phase the realm will apply to a transaction landing at `now`.
export function phaseAt(a: Auction, now: number): Phase {
  if (a.settled) return "Settled";
  if (now < a.commitEnd) return "Commit";
  if (now < a.revealEnd) return "Reveal";
  return "Ready to settle";
}
