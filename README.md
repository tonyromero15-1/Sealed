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
their change, losers get a refund, and the seller gets proceeds plus unsold
tokens. Unrevealed bids lose 10% of their deposit (anti-spam).

Built for the Gnome Tavern hackathon (Gno.land × DoraHacks). Written in Gno
for the Onyx testnet.

## Example (from the local demo)

1,000 TAVERN for sale, reserve 1 GNOT. Five sealed bids, one never revealed:

| Bidder | Bid | Wanted | Won | Pays (at 2 GNOT) | Result |
|---|---:|---:|---:|---:|---|
| alice | 3 GNOT | 300 | 300 | 600 GNOT | Won |
| bob | 2.5 GNOT | 250 | 250 | 500 GNOT | Won |
| carol | 2 GNOT | 400 | 300 | 600 GNOT | Partial (pro-rata tie) |
| dave | 2 GNOT | 200 | 150 | 300 GNOT | Partial (pro-rata tie) |
| erin | sealed | — | 0 | 0 | No reveal: loses 200 of 2,000 GNOT |

Clearing price is **2 GNOT** for everyone. Alice bid 3 but pays 2, so there's
no reason to race or overpay. The full page output for every phase is in
[`docs/LOCAL-DEMO.md`](docs/LOCAL-DEMO.md).

## Layout

```
realms/sealed/    gno.land/r/dev/sealed: the auction realm
  sealed.gno        types, CreateAuction / Commit / Reveal / Settle / Claim
  settle.gno        clearing price, pro-rata split, outcomes
  render.gno        gnoweb pages (home + auction page)
  sealed_test.gno   17 tests
realms/tavern/    gno.land/r/dev/tavern: demo GRC20 (TAVERN) with a faucet
scripts/
  setup-gno.sh      install gno/gnokey/gnodev at Onyx's version
  demo-local.sh     full lifecycle on gnodev with 6 throwaway accounts
  commitment.sh     make a commitment hash locally
  set-namespace.sh  switch r/dev/ to your g1 address before an Onyx deploy
docs/
  RESEARCH.md       Onyx details, current Gno syntax, reference projects
  LOCAL-DEMO.md     Render output of every demo phase
```

## API

| Function | Who | What |
|---|---|---|
| `CreateAuction(token, supply, reservePrice, commitEnd, revealEnd) uint64` | seller | Escrows `supply` of the GRC20 `token` (its grc20reg key, e.g. `gno.land/r/dev/tavern.TAVERN`). Approve `Address()` on the token first. Times are Unix seconds. |
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
gno test ./realms/...           # 17 tests
scripts/demo-local.sh           # full lifecycle on gnodev, pages saved to demo-out/
```

Make a bid by hand against a running `gnodev`:

```sh
scripts/commitment.sh g1YOURADDR 2000000 100        # prints salt + commitment
gnokey maketx call -pkgpath gno.land/r/dev/sealed -func Commit \
  -args 1 -args <commitment> -send 200000000ugnot \
  -gas-fee 1000000ugnot -gas-wanted 50000000 -broadcast -chainid dev -remote 127.0.0.1:26657 KEY
```

## Status

- [x] Day 1: research, realm, tests, local demo
- [ ] Day 2: deploy to Onyx (`scripts/set-namespace.sh g1…`), web frontend
- [ ] Demo video, submission (target Dec 16)

Keys in this repo: none. `.gitignore` blocks key files. Every key used so
far was a throwaway local key.
