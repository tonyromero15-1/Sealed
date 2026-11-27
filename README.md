# SEALED

**Sealed-bid token launches. Speed becomes worthless.**

On-chain launches reward speed: snipers and bots buy first, and humans lose.
SEALED runs a token launch as a **sealed-bid, uniform-price auction** on
[Gno.land](https://gno.land):

1. **Commit.** Buyers post only `sha256(bidder|price|amount|salt)` plus a
   GNOT deposit. Nobody can see any bid.
2. **Reveal.** Buyers open their bids. The realm re-hashes each one and checks
   it against the commitment, and checks that the deposit covers
   `price × amount`.
3. **Settle.** Anyone can trigger it. Bids fill from the highest price down
   until supply runs out. **Every winner pays the same clearing price**, the
   lowest filled bid. Ties at that price split pro-rata. Being first means
   nothing.

Then everyone pulls their own funds with `Claim`: winners get tokens plus
their change, losers get a refund, and the seller gets the sale proceeds plus
unsold tokens.

**No-shows:** a bid that is committed but never revealed loses 10% of its
deposit. That forfeit goes to the **winners, in proportion to tokens won**,
never to the seller. So a seller who fakes demand with bids that never reveal
only pays the real buyers. If nobody wins, the forfeit is **burned**: it stays
locked in the realm, and no one can withdraw it.

Built for the Gnome Tavern hackathon (Gno.land × DoraHacks). Written in Gno
for the Onyx testnet.

## Example (from the local demo)

100 TAVERN for sale, reserve 0.05 GNOT. Five sealed bids, one never revealed:

| Bidder | Bid | Wanted | Won | Pays (at 0.2 GNOT) | Forfeit share | Result |
|---|---:|---:|---:|---:|---:|---|
| alice | 0.3 GNOT | 30 | 30 | 6 GNOT | +0.6 GNOT | Won |
| bob | 0.25 GNOT | 25 | 25 | 5 GNOT | +0.5 GNOT | Won |
| carol | 0.2 GNOT | 40 | 30 | 6 GNOT | +0.6 GNOT | Partial (pro-rata tie) |
| dave | 0.2 GNOT | 20 | 15 | 3 GNOT | +0.3 GNOT | Partial (pro-rata tie) |
| erin | sealed | — | 0 | 0 | — | No reveal: loses 2 of 20 GNOT |

Clearing price is **0.2 GNOT** for everyone. Alice bid 0.3 but pays 0.2, so
there's no reason to race or overpay. The seller receives exactly the 20 GNOT
of sales. Every phase's page output is in [`docs/LOCAL-DEMO.md`](docs/LOCAL-DEMO.md).

## Known limitations

- **Reveals are public as they happen.** During the reveal window, later
  revealers can see earlier bids before deciding to reveal. Not revealing
  costs 10%, which limits this, but it is still information.
- **Deposits show maximum size.** A deposit is visible during the commit
  phase and caps `price × amount`. Bidders can over-deposit to hide their
  real bid. The extra is refunded.
- **Future work: encrypted bids.** For example, threshold or timelock
  encryption, so nothing about any bid leaks until settlement and no
  separate reveal step is needed.
- **The token's own realm controls its ledger.** A malicious token could
  burn escrowed tokens. SEALED is only as trustworthy as the token being sold.
- **Pro-rata rounding dust** (under 1 token per tied bidder) returns to the
  seller as unsold. Forfeit rounding dust is burned.
- **Up to 200 bids per auction**, so `Settle` always fits in a block.

## Layout

```
realms/sealed/    gno.land/r/<ns>/sealed/v1: the auction realm
  sealed.gno        types, CreateAuction / Commit / Reveal / Settle / Claim
  settle.gno        clearing price, pro-rata split, forfeit shares
  render.gno        gnoweb pages (home + auction page)
  sealed_test.gno   20 tests
realms/tavern/    gno.land/r/<ns>/tavern/v1: demo GRC20 (TAVERN) with a faucet
scripts/
  setup-gno.sh      install gno/gnokey/gnodev at Onyx's version
  demo-local.sh     full lifecycle on gnodev with 6 throwaway accounts
  deploy-onyx.sh    deploy tavern + sealed to onyx-1 (source files only)
  commitment.sh     make a commitment hash locally
  set-namespace.sh  switch the namespace (Onyx needs your g1 address)
  rpc-relay.py      only for sandboxes where gnokey can't use the HTTPS proxy
docs/
  RESEARCH.md       Onyx details, current Gno syntax, reference projects
  LOCAL-DEMO.md     Render output of every demo phase
  DEPLOYMENTS.md    Onyx package paths, tx hashes, status
```

Paths are versioned (`.../sealed/v1`), so a fix ships as `v2` next to it
instead of replacing deployed code. `<ns>` is currently
`g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40`, the testnet deployer address.

## API

| Function | Who | What |
|---|---|---|
| `CreateAuction(token, supply, reservePrice, commitEnd, revealEnd) uint64` | seller | Escrows `supply` of the GRC20 `token` (its grc20reg key, e.g. `gno.land/r/<ns>/tavern/v1.TAVERN`). Approve `Address()` on the token first. Times are Unix seconds. |
| `Commit(id, commitment)` + `-send <deposit>ugnot` | bidder | One sealed bid per address. Deposit ≥ 0.1 GNOT. |
| `Reveal(id, price, amount, salt)` | bidder | Must match the commitment, and deposit must be ≥ `price × amount`. |
| `Settle(id)` | anyone | After the reveal window closes. Moves no funds. |
| `Claim(id)` | bidder / seller | Pulls what you're owed. Settles first if needed. |
| `MakeCommitment(bidder, price, amount, salt)` | read-only | Same hash as `scripts/commitment.sh`. |

Units: `price` and `reservePrice` are **ugnot per token unit**
(1 GNOT = 1,000,000 ugnot). `supply` and `amount` are token units.

## Run it

```sh
scripts/setup-gno.sh            # once: tools at Onyx's version + offline package cache
gno test ./realms/...           # 20 tests
scripts/demo-local.sh           # full lifecycle on gnodev, pages saved to demo-out/
scripts/deploy-onyx.sh <key>    # deploy to onyx-1 (after set-namespace.sh <your g1 addr>)
```

Make a bid by hand against a running `gnodev`:

```sh
scripts/commitment.sh g1YOURADDR 200000 10          # prints salt + commitment
gnokey maketx call -pkgpath gno.land/r/<ns>/sealed/v1 -func Commit \
  -args 1 -args <commitment> -send 2000000ugnot \
  -gas-fee 1000000ugnot -gas-wanted 50000000 -broadcast -chainid dev -remote 127.0.0.1:26657 KEY
```

## Status

- [x] Day 1: research, realm, tests, local demo
- [x] Day 2: forfeits to winners (not seller), versioned paths, deploy tooling
- [x] Day 2: **live on onyx-1**:
  [sealed/v1](https://onyx.testnets.gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1),
  [tavern/v1](https://onyx.testnets.gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1)
  (tx hashes in [`docs/DEPLOYMENTS.md`](docs/DEPLOYMENTS.md))
- [ ] Web frontend, demo video, submission (target Dec 16)

Keys in this repo: none. `.gitignore` blocks key files. The deployer is a
testnet-only key kept outside the repo.
