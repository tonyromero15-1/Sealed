# SEALED: Day 1 research

Researched on 2026-11-25 from the Gno source (the `v1.8.0-rc.1` tag Onyx runs,
plus `chain/mainnet` and `master`), and two reference projects. All facts
below were read from those sources. The Gno websites and the Onyx RPC were
blocked by this environment's network policy, so nothing here was checked
against the live chain yet (see "Blocked domains").

## 1. Tooling installed

| Tool | Version | How |
|---|---|---|
| `gno` | v1.8.0 (built from tag `v1.8.0-rc.1`, commit `fc79041f4`) | `make install` in a clone of gnolang/gno |
| `gnokey` | same | same |
| `gnodev` | same | same |
| Go | 1.25.9 (auto-downloaded toolchain; the repo needs ≥ 1.25.9) | `GOTOOLCHAIN=auto` |

We build the tools from the **exact tag Onyx runs**, not `master`. `master`
is already ahead of the chain, and its examples differ from what's deployed.

`scripts/setup-gno.sh` repeats the whole install on a fresh machine. It also
fills gno's package cache from that tag's `examples/`. By default `gno test`
downloads imports from `rpc.gno.land`, which is blocked here (and is mainnet,
not Onyx).

### Blocked domains (network policy, HTTP 403 from the proxy)

- `rpc.onyx.testnets.gno.land` (Onyx RPC, needed Day 2 to deploy)
- `onyx.testnets.gno.land` (Onyx gnoweb, where the demo pages will live)
- `faucet.gno.land` (test GNOT)
- `docs.gno.land`, `gno.land`, `rpc.gno.land`
- `gnoscan.io` (explorer)
- `dorahacks.io`

Reachable: `github.com`, `api.github.com`, `proxy.golang.org`.
Allow at least `rpc.onyx.testnets.gno.land` and `rpc.latest.testnets.gno.land`
before Day 2. The others are nice to have.

## 2. Onyx testnet

| | |
|---|---|
| Chain ID | `onyx-1` |
| RPC | `https://rpc.onyx.testnets.gno.land:443` (alias: `https://rpc.latest.testnets.gno.land:443`) |
| Web (gnoweb) | `https://onyx.testnets.gno.land` (alias `https://latest.testnets.gno.land`) |
| Faucet | `https://faucet.gno.land`: pick the testnet, paste your `g1…` address. Rate-limited per address. FairDrop reports 50 GNOT per grant. |
| Explorer | `https://gnoscan.io` (Onyx support not verified, blocked) |
| Package approval status | `https://gpas.latest.testnets.gno.land` (look up your package path) |
| Version | `v1.8.0-rc.1` since block 1,203,400 (2026-11-17). Runs mainnet's code. |
| Launched | 2026-09-28. State persists across upgrades. |

### Three Onyx rules that change our plan

1. **No custom namespace.** You can only deploy under your own address:
   `gno.land/r/g1<your-address>/sealed`. Name registration is not open, and
   `r/sys/users` only hands out `nym-…` pseudonyms. So we develop as
   `gno.land/r/dev/sealed`, and `scripts/set-namespace.sh g1…` rewrites the
   paths before deploying.
2. **Deploys are "parked" until approved.** Onyx runs
   `code_submission_policy = inert`. An `addpkg` is accepted and paid for, but
   the package can't be called until an approver sends `MsgEnablePackage`.
   The docs say an approval bot (gpao) does this within seconds. FairDrop's
   real experience: parked about a day, with a queue of 130+ packages and
   hand-operated approvers. **Deploy early on Day 2.** If it stays parked, ask
   in the Gno.land Discord `#gnome-tavern-hackathon` with the tx hashes.
   Approval is tied to the exact source hash, so **do not redeploy the same
   path after asking**.
3. **`maketx run` is restricted** (only the GovDAO seed member). Every
   interaction must be a plain `maketx call`. Our realm only uses calls.

### Deploying (Day 2)

```sh
scripts/set-namespace.sh g1YOURADDRESS
gnokey maketx addpkg -pkgpath gno.land/r/g1YOURADDRESS/tavern -pkgdir realms/tavern \
  -gas-fee 10000000ugnot -gas-wanted 50000000 -broadcast \
  -chainid onyx-1 -remote https://rpc.onyx.testnets.gno.land:443 YOURKEY
# then the same for realms/sealed (tavern first: it's the demo token)
```

Each byte stored locks a 100 ugnot storage deposit, so a deploy costs a few
GNOT. Check that the package went live with
`gnokey query vm/qrender --data "gno.land/r/g1YOURADDRESS/sealed:" -remote …`.
A parked package answers `package_parked`.

### Packages available on Onyx

Onyx has mainnet's package set only. New `p/nt/*` packages can't be added
after genesis. Everything we import is there:

- realm: `p/nt/avl/v0`, `p/nt/seqid/v0`, `r/nt/grc20reg/v0`, stdlib
- tavern: `p/nt/grc20/v0`, `p/nt/ufmt/v0`, `r/nt/grc20reg/v0`
- tests only: `p/nt/testutils/v0`, `p/nt/uassert/v0`, `p/nt/urequire/v0`
  (Onyx includes them as test deps of grc20)

`gno.land/p/demo/...` paths from older tutorials (for example
`p/demo/tokens/grc20`) are **not** on Onyx.

## 3. Current Gno syntax (v1.8, what we used)

**Crossing functions.** A public function that changes state takes
`cur realm` as its first parameter:

```go
func Commit(cur realm, auctionID uint64, commitment string) { ... }
```

- From the CLI (`gnokey maketx call`) the chain crosses for you.
- From Gno code in another realm, cross explicitly: `sealed.Commit(cross(cur), 1, hash)`.
- `cur.Previous()` is the caller (a `runtime.Realm`): `.Address()`,
  `.PkgPath()`, `.IsUserCall()` (direct `maketx call` from a wallet).
- `cur.Address()` is this realm's own address. `cur.PkgPath()` is its path.
- `func init(cur realm)` gets the realm handle at deploy time.
- Helpers that need the realm take it as a non-first parameter
  (`func f(_ int, rlm realm)` or `func f(t *testing.T, rlm realm)`). A
  first parameter named `cur` makes a function crossing.

**`address`** is a builtin type (bech32 string): `addr.String()`, `address("g1…")`.

**The old `std` package is gone.** It was split into:

| Package | What we use |
|---|---|
| `chain` | `chain.Coins{{"ugnot", n}}`, `chain.Emit(event, k, v…)`, `chain.PackageAddress(path)` |
| `chain/banker` | `banker.NewBanker(banker.BankerTypeRealmSend, cur).SendCoins(from, to, coins)` and `banker.NewReadonlyBanker()` |
| `chain/runtime` | `runtime.ChainHeight()`, `runtime.AssertOriginCall()` |
| `chain/runtime/unsafe` | `unsafe.OriginSend()` (coins attached to the tx), `unsafe.OriginCaller()` |

**Native coins in.** The user attaches GNOT with `gnokey … -send 5000000ugnot`.
The coins land on the realm's address before the code runs. The realm reads
them with `unsafe.OriginSend()`. That envelope is shared by every realm in a
call chain, so pair it with `cur.Previous().IsUserCall()`. The docs say this
explicitly, and gnomemepad does the same.

**Native coins out.** `banker.NewBanker(banker.BankerTypeRealmSend, cur)` can
only send from the realm's own address.

**GRC20** (`gno.land/p/nt/grc20/v0`):

```go
Token, ledger := grc20.NewToken("Tavern Token", "TAVERN", 0 /*decimals*/, 0 /*id*/, cur)
key := grc20reg.Register(cross(cur), Token, "") // key = "<realm path>.TAVERN"
ledger.Mint(addr, n)
ledger.CallerTeller().Transfer(0, cur, to, n)  // inside the token realm
```

Another realm (SEALED) moves a user's tokens through the registry, as itself:

```go
grc20reg.TransferFrom(0, cur, key, seller, cur.Address(), n) // seller approved SEALED first
grc20reg.Transfer(0, cur, key, winner, n)                    // pays out of SEALED's balance
```

These take `(_ int, rlm realm, …)` on purpose: non-crossing, with the
caller's own `cur`, so the realm can only ever spend its own balance or
allowance.

**sha256.** `crypto/sha256.Sum256([]byte) [32]byte`, then
`encoding/hex.EncodeToString(sum[:])`. Also available: `math/bits`
(128-bit `Mul64`/`Div64`, used for overflow-free pro-rata math),
`math/overflow` (`Add64`, `Mul64` with ok flag), `sort.Sort` (there is no
`sort.Slice`), `strconv`, `time.Now()` = block time.

**Tests** (`gno test ./realms/...`):

- `func TestX(cur realm, t *testing.T)`
- `testing.SetRealm(testing.NewUserRealm(addr))` sets who signs the next
  call. **Gotcha we hit:** it only works when written directly in the test
  body. Called inside a helper it silently does nothing.
- `testing.SetOriginSend(coins)` fakes `-send`, but no coins move, so also
  `testing.IssueCoins(realmAddr, coins)`.
- `testing.SkipHeights(n)` advances height and +5 s of block time per block.
- `uassert.AbortsContains(t, cur, "msg", func() { F(cross(cur), …) })` checks
  a rejected call.

**Packages** need a `gnomod.toml`: `module = "gno.land/r/…"` and `gno = "0.9"`.
A `gnowork.toml` at the repo root lets local realms import each other.

## 4. Reference projects (studied, not copied)

### gnomemepad (`sunny-0x42/gnomemepad`)
A working bonding-curve launchpad on Gno testnets and mainnet.
- Payments: `cur.Previous().IsUserCall()` guard, then `unsafe.OriginSend()`.
  Payouts via `BankerTypeRealmSend`. Same pattern we use.
- Tokens: `grc20.NewToken(..., cur)` plus `grc20reg.Register(cross(cur), token, symbol)`.
  Their notes say wallets (Adena) and DEXes find tokens **only** through the
  grc20reg key `pkgpath.SYMBOL`. So SEALED identifies tokens by that key.
- Keeps one deploy tree per testnet under `deploy/<net>/r/<g1addr>/…`, with
  scripts that rewrite import paths. That's the same personal-namespace
  constraint we handle with `set-namespace.sh`.
- Uses `runtime.ChainHeight()` for timing. We use block time instead
  (deadlines read better as clock times).

### FairDrop (`dorithesky/gno-fairdrop`, a Gnome Tavern entry)
A commit-reveal raffle board.
- Seal = sha256 over a domain-separated string, with a **minimum secret
  length** so a public seal can't be brute-forced. We kept the spec's format
  `sha256(bidder|price|amount|salt)` and require an 8 to 128 character salt.
- Missed reveal = forfeit, plus block-time deadlines. Same as us.
- Ships an off-chain verifier that recomputes the result from chain data.
  This is a good Day 3+ idea for us: `scripts/verify` recomputing the
  clearing price.
- Their Onyx run: deployed 11-24, parked, enabled by a human approver 11-25.
  This is where the "deploy early" warning comes from.

## 5. Known limits (to mention honestly in the submission)

- **Deposits are public.** A deposit is an upper bound on price × amount.
  Bidders can over-deposit to hide their real size. The extra is refunded.
- **Pro-rata rounding dust** (under 1 unit per tied bidder) is not handed
  out by any order. It goes back to the seller as unsold.
- **Forfeits go to the seller.** No-shows can't be caused by the seller, so
  this doesn't create a bad incentive.
- **The token's own realm controls its ledger.** A malicious token could burn
  escrowed tokens. SEALED is only as trustworthy as the token being sold.
- **gnodev countdowns can look frozen.** Page queries read the time of the
  last block that included transactions, so "time left" may not tick between
  transactions locally. The on-chain deadline checks use real block time
  (verified in the demo). The Day 2 frontend should run the countdown
  client-side from the absolute end times.
- **MaxBidsPerAuction = 200** keeps `Settle` within gas.
