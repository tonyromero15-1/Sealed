# SEALED web (bidder page)

Vite + React + TypeScript + Tailwind. Reads the SEALED realm straight from
the Onyx RPC and sends transactions through the
[Adena](https://docs.adena.app) wallet. Not deployed yet.

```sh
cd web
npm install
npm run dev        # http://localhost:5173
npm test           # vitest: commitment matches the realm, money formatting
npm run build      # static site in dist/
```

Config (optional `.env.local`):

| Var | Default |
|---|---|
| `VITE_RPC_URL` | `https://rpc.onyx.testnets.gno.land:443` |
| `VITE_CHAIN_ID` | `onyx-1` |
| `VITE_REALM_PATH` | `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1` |
| `VITE_GNOWEB_URL` | `https://onyx.testnets.gno.land` |

## What it does

- **Wallet:** `window.adena`. It connects (`AddEstablish`), adds or switches
  Adena to Onyx (`AddNetwork` / `SwitchNetwork`), and sends calls with
  `DoContract` pinned to onyx-1 via `networkInfo`.
- **Auction list and page:** phase, a live countdown (computed client-side
  from the on-chain end times), the sealed bid count (contents hidden), your
  own bid's status, and a results table after settlement.
- **Seal my bid:** price and amount, plus an optional "hide my size" extra
  deposit.
  1. The page makes a random 16-byte salt.
  2. It computes `sha256(address|price|amount|salt)` exactly like the realm.
  3. It saves `{auction, price, amount, salt, …}` to localStorage **and**
     downloads a backup JSON file.
  4. The send button stays locked until the user confirms they saved the
     backup, then the page calls `Commit` with the deposit.
- **Reveal my bid:** uses the saved bid, or an uploaded backup file. It checks
  locally that the backup re-hashes to your on-chain commitment before
  sending `Reveal`.
- **Settle** (anyone, once the reveal window closes) and **Claim** (shows
  tokens, refund and forfeit share first).

`src/lib/commitment.test.ts` proves the page hashes exactly like the realm,
using vectors the realm itself produced on onyx-1. The Gno side asserts the
same vector in `TestCommitmentMatchesWebVector`.

## What the realm is missing (batch into v2)

v1 has no exported "read auction as data" function, so the page reads
through `vm/qeval` using the realm's **unexported** names. This works on the
deployed v1 (qeval runs read-only in the package scope), but it ties the page
to private details. For v2:

1. `AuctionCount() int` and an exported `GetAuction(id)`, ideally one call
   returning JSON. Today: `auctions.Size()` and a composite of
   `mustGetAuction(id).<fields>`.
2. `GetBid(id, addr)` returning the bid plus its outcome (filled, cost,
   refund, forfeit share, status, claimed). Today: `getBid` / `outcomeOf`.
3. `BidderAt(id, i)` or a paged bidder list for the results table. Today:
   `bids.GetByIndex(i)`.
4. Plain numbers from read functions. The only string helpers reachable from
   qeval are the page formatters (`formatInt` adds commas, `check` returns
   ✓ or —), because `strconv` isn't in qeval's scope.

None of these block the page today.
