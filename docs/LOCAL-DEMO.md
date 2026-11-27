# SEALED: local demo transcript

Produced by `scripts/demo-local.sh` on a local gnodev chain (Gno `v1.8.0`,
the Onyx version), at the same package paths we deploy to Onyx. Six
throwaway accounts: one seller and five bidders. Every step is a real signed
transaction (`gnokey maketx call`). The pages below are the realm's
`Render()` output, captured with `gnokey query vm/qrender` after each phase.

Setup, sized to fit the Onyx faucet (100 to 300 GNOT per request): 100
TAVERN for sale, reserve price 0.05 GNOT, commit window 45 s, reveal window
40 s.

| Bidder | Sealed bid | Deposit | Reveals? |
|---|---|---:|---|
| alice | 0.3 GNOT × 30 | 10 GNOT (over-deposit hides her size) | yes |
| bob | 0.25 GNOT × 25 | 6.25 GNOT | yes |
| carol | 0.2 GNOT × 40 | 8 GNOT | yes |
| dave | 0.2 GNOT × 20 | 4 GNOT | yes |
| erin | 0.4 GNOT × 50 | 20 GNOT | **no** (sniper no-show) |

Accounts:

```
sealed realm: gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1 (g19ewgjgpz7duvzr7w9wk356yclhu40gs00wr6wl)
seller: g18929gm67elrfd2kqg9m5lqn8s4ur6eg2yyygkq
alice: g1pq57mdzlknct899zz0rncstuhjur909g7n0eur
bob: g1utndt05ceugr5ss8wtfvrgz2n89sq8mswrgr46
carol: g1zdvzgwkj2dd3m5l06yvz3wkejfyg6lr4mum9qq
dave: g1xn0awj4vkt0w38uyu9fxyqnku4p7exwy8r6fu9
erin: g1qett30vjk4wq22zzytzapahuujntdefwgdzha9
```

> Note on "time left": gnodev page queries read the time of the last block
> that included transactions, so the countdown only moves when a tx lands.
> Deadlines are enforced with real block time (see the tests).

## 1. Auction created (commit phase, no bids yet)

```markdown
# SEALED

*Sealed-bid token launches. Speed becomes worthless.*

Bots win normal launches by buying first. Here, being first means nothing:

1. **Commit:** post a hash of your bid plus a GNOT deposit. Nobody can see any bid.
2. **Reveal:** open your bid. The realm checks it against your hash.
3. **Settle:** highest bids fill first, and **every winner pays the same clearing price**.

## Auctions

| Auction | Token | Supply | Reserve | Phase | Time left | Sealed bids |
|---|---|---:|---:|---|---|---:|
| [#1](/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1:auction/1) | TAVERN | 100 | 0.05 GNOT | 🔒 Commit | 45s | 0 |

---

**Launch a token:** approve `g19ewgjgpz7duvzr7w9wk356yclhu40gs00wr6wl` on your GRC20 for the sale supply, then call `CreateAuction`.
```

```markdown
# Auction #1: 100 TAVERN

[← All auctions](/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1)

**🔒 Commit** · 45s left

- **Token:** `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1.TAVERN`
- **Seller:** `g18929gm…ygkq`
- **Supply:** 100 TAVERN
- **Reserve price:** 0.05 GNOT per TAVERN
- **Commit ends:** 2026-11-26 20:55:45 UTC
- **Reveal ends:** 2026-11-26 20:56:25 UTC

## 🔒 0 sealed bids

Bid contents stay hidden. Only the count is public.

**To bid:** compute `sha256(yourAddress|price|amount|salt)` on your own machine, then call `Commit(1, <hash>)` and send a GNOT deposit of at least price × amount (deposit more to hide your bid size; the extra is refunded).
```

## 2. After 5 sealed commits

Only the count is public.

```markdown
# SEALED

*Sealed-bid token launches. Speed becomes worthless.*

Bots win normal launches by buying first. Here, being first means nothing:

1. **Commit:** post a hash of your bid plus a GNOT deposit. Nobody can see any bid.
2. **Reveal:** open your bid. The realm checks it against your hash.
3. **Settle:** highest bids fill first, and **every winner pays the same clearing price**.

## Auctions

| Auction | Token | Supply | Reserve | Phase | Time left | Sealed bids |
|---|---|---:|---:|---|---|---:|
| [#1](/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1:auction/1) | TAVERN | 100 | 0.05 GNOT | 🔒 Commit | 44s | 5 |

---

**Launch a token:** approve `g19ewgjgpz7duvzr7w9wk356yclhu40gs00wr6wl` on your GRC20 for the sale supply, then call `CreateAuction`.
```

```markdown
# Auction #1: 100 TAVERN

[← All auctions](/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1)

**🔒 Commit** · 44s left

- **Token:** `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1.TAVERN`
- **Seller:** `g18929gm…ygkq`
- **Supply:** 100 TAVERN
- **Reserve price:** 0.05 GNOT per TAVERN
- **Commit ends:** 2026-11-26 20:55:45 UTC
- **Reveal ends:** 2026-11-26 20:56:25 UTC

## 🔒 5 sealed bids

Bid contents stay hidden. Only the count is public.

**To bid:** compute `sha256(yourAddress|price|amount|salt)` on your own machine, then call `Commit(1, <hash>)` and send a GNOT deposit of at least price × amount (deposit more to hide your bid size; the extra is refunded).
```

## 3. Reveal phase (4 of 5 revealed, erin never shows)

```markdown
# Auction #1: 100 TAVERN

[← All auctions](/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1)

**🔓 Reveal** · 37s left

- **Token:** `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1.TAVERN`
- **Seller:** `g18929gm…ygkq`
- **Supply:** 100 TAVERN
- **Reserve price:** 0.05 GNOT per TAVERN
- **Commit ends:** 2026-11-26 20:55:45 UTC
- **Reveal ends:** 2026-11-26 20:56:25 UTC

## 🔓 Reveal phase

**4 of 5** sealed bids revealed.

Call `Reveal(1, price, amount, salt)` before the window closes. A bid that is never revealed loses 10% of its deposit.
```

## 4. Reveal window closed

```markdown
# Auction #1: 100 TAVERN

[← All auctions](/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1)

**⏳ Ready to settle**

- **Token:** `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1.TAVERN`
- **Seller:** `g18929gm…ygkq`
- **Supply:** 100 TAVERN
- **Reserve price:** 0.05 GNOT per TAVERN
- **Commit ends:** 2026-11-26 20:55:45 UTC
- **Reveal ends:** 2026-11-26 20:56:25 UTC

## ⏳ Reveal closed

**4 of 5** sealed bids revealed. Anyone can now call `Settle(1)`.
```

## 5. Settled (bob, a bidder, pressed Settle, but anyone can)

```markdown
# Auction #1: 100 TAVERN

[← All auctions](/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1)

**✅ Settled**

- **Token:** `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1.TAVERN`
- **Seller:** `g18929gm…ygkq`
- **Supply:** 100 TAVERN
- **Reserve price:** 0.05 GNOT per TAVERN
- **Commit ends:** 2026-11-26 20:55:45 UTC
- **Reveal ends:** 2026-11-26 20:56:25 UTC

## ✅ Results

| Clearing price | Sold | Total raised |
|---:|---:|---:|
| **0.2 GNOT** | 100 / 100 TAVERN | 20 GNOT |

Every winner pays **0.2 GNOT per TAVERN**, the lowest accepted bid, however high they bid and whenever they committed.

- **Seller proceeds:** 20 GNOT (unclaimed)
- **Unsold, back to seller:** 0 TAVERN
- **Forfeits from no-shows:** 2 GNOT, shared by the winners in proportion to tokens won (never the seller)

### Bids

| Bidder | Bid price | Wanted | Won | Pays | Refund | Forfeit share | Result | Claimed |
|---|---:|---:|---:|---:|---:|---:|---|:---:|
| `g1pq57md…0eur` | 0.3 GNOT | 30 | 30 | 6 GNOT | 4 GNOT | +0.6 GNOT | 🏆 Won | — |
| `g1utndt0…gr46` | 0.25 GNOT | 25 | 25 | 5 GNOT | 1.25 GNOT | +0.5 GNOT | 🏆 Won | — |
| `g1xn0awj…6fu9` | 0.2 GNOT | 20 | 15 | 3 GNOT | 1 GNOT | +0.3 GNOT | 🌗 Partial fill | — |
| `g1zdvzgw…m9qq` | 0.2 GNOT | 40 | 30 | 6 GNOT | 2 GNOT | +0.6 GNOT | 🌗 Partial fill | — |
| `g1qett30…zha9` | sealed | — | 0 | 0 GNOT | 18 GNOT | — | ⚠️ No reveal (-10%) | — |

Winners and refunds: call `Claim(1)`.
```

What happened: alice (0.3) and bob (0.25) fill completely, using 55 of the
100. Carol and dave tie at 0.2 GNOT, wanting 60 for the 45 left, so they
split pro-rata: carol 40×45/60 = 30 and dave 20×45/60 = 15. The clearing
price is the lowest filled bid, **0.2 GNOT, and everyone pays it**: alice
pays 6 GNOT, not 9. Erin's sealed 0.4 GNOT bid never counted. She gets 18
GNOT back, and her 2 GNOT forfeit goes to the **winners by tokens won**
(30/25/30/15 of 100). The seller gets only the 20 GNOT of sales.

## 6. After everyone claimed

```markdown
# Auction #1: 100 TAVERN

[← All auctions](/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1)

**✅ Settled**

- **Token:** `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1.TAVERN`
- **Seller:** `g18929gm…ygkq`
- **Supply:** 100 TAVERN
- **Reserve price:** 0.05 GNOT per TAVERN
- **Commit ends:** 2026-11-26 20:55:45 UTC
- **Reveal ends:** 2026-11-26 20:56:25 UTC

## ✅ Results

| Clearing price | Sold | Total raised |
|---:|---:|---:|
| **0.2 GNOT** | 100 / 100 TAVERN | 20 GNOT |

Every winner pays **0.2 GNOT per TAVERN**, the lowest accepted bid, however high they bid and whenever they committed.

- **Seller proceeds:** 20 GNOT (claimed ✓)
- **Unsold, back to seller:** 0 TAVERN
- **Forfeits from no-shows:** 2 GNOT, shared by the winners in proportion to tokens won (never the seller)

### Bids

| Bidder | Bid price | Wanted | Won | Pays | Refund | Forfeit share | Result | Claimed |
|---|---:|---:|---:|---:|---:|---:|---|:---:|
| `g1pq57md…0eur` | 0.3 GNOT | 30 | 30 | 6 GNOT | 4 GNOT | +0.6 GNOT | 🏆 Won | ✓ |
| `g1utndt0…gr46` | 0.25 GNOT | 25 | 25 | 5 GNOT | 1.25 GNOT | +0.5 GNOT | 🏆 Won | ✓ |
| `g1xn0awj…6fu9` | 0.2 GNOT | 20 | 15 | 3 GNOT | 1 GNOT | +0.3 GNOT | 🌗 Partial fill | ✓ |
| `g1zdvzgw…m9qq` | 0.2 GNOT | 40 | 30 | 6 GNOT | 2 GNOT | +0.6 GNOT | 🌗 Partial fill | ✓ |
| `g1qett30…zha9` | sealed | — | 0 | 0 GNOT | 18 GNOT | — | ⚠️ No reveal (-10%) | ✓ |

Winners and refunds: call `Claim(1)`.
```

```markdown
# SEALED

*Sealed-bid token launches. Speed becomes worthless.*

Bots win normal launches by buying first. Here, being first means nothing:

1. **Commit:** post a hash of your bid plus a GNOT deposit. Nobody can see any bid.
2. **Reveal:** open your bid. The realm checks it against your hash.
3. **Settle:** highest bids fill first, and **every winner pays the same clearing price**.

## Auctions

| Auction | Token | Supply | Reserve | Phase | Time left | Sealed bids |
|---|---|---:|---:|---|---|---:|
| [#1](/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1:auction/1) | TAVERN | 100 | 0.05 GNOT | ✅ Settled | — | 5 |

---

**Launch a token:** approve `g19ewgjgpz7duvzr7w9wk356yclhu40gs00wr6wl` on your GRC20 for the sale supply, then call `CreateAuction`.
```

TAVERN balances after claims (the seller started with 10,000 from the faucet
and escrowed 100):

```
seller: (9900 int64)
alice: (30 int64)
bob: (25 int64)
carol: (30 int64)
dave: (15 int64)
erin: (0 int64)
sealed escrow: (0 int64)
```

The SEALED escrow is back to 0: every token and every ugnot was paid out.

## Transaction log

```
== starting gnodev
== seller: faucet + approve SEALED for 100 TAVERN
OK!
GAS USED:   4879633
OK!
GAS USED:   5350490
== seller: CreateAuction(100 TAVERN, reserve 0.05 GNOT)
(1 uint64)
OK!
GAS USED:   10272764
== alice: Commit(sealed hash 1da7ca15947e311a99f0fbdebc4be2e91c6954dacf2beea01d9e36b00a208238, deposit 10000000ugnot)
OK!
GAS USED:   7513703
== bob: Commit(sealed hash 21e12b13531bd3ea0b9937cb2f86ada1dd652c414c2b9a7890649e0f4bee371c, deposit 6250000ugnot)
OK!
GAS USED:   7445042
== carol: Commit(sealed hash d08d14352da3a116a860891dc3e3fb98726a5216e0f42b38f7a246a4105b58c3, deposit 8000000ugnot)
OK!
GAS USED:   7971092
== dave: Commit(sealed hash 02bd6fde85cdca8b347efb5686c2b25ee31990560603fce2710002ec2aac96d2, deposit 4000000ugnot)
OK!
GAS USED:   8611502
== erin: Commit(sealed hash e19c90c17367f7bea8ca7001592880860a24f3417ab79f8b7561ea404d855adb, deposit 20000000ugnot)
OK!
GAS USED:   8502495
== waiting for the commit phase to end
== alice: Reveal(300000, 30, salt)
OK!
GAS USED:   7036651
== bob: Reveal(250000, 25, salt)
OK!
GAS USED:   6891111
== carol: Reveal(200000, 40, salt)
OK!
GAS USED:   6893162
== dave: Reveal(200000, 20, salt)
OK!
GAS USED:   6958388
== waiting for the reveal window to close
== bob (anyone): Settle
OK!
GAS USED:   8583801
== alice: Claim
OK!
GAS USED:   10924599
== bob: Claim
OK!
GAS USED:   11362060
== carol: Claim
OK!
GAS USED:   11833056
== dave: Claim
OK!
GAS USED:   12458059
== erin: Claim
OK!
GAS USED:   7278326
== seller: Claim
OK!
GAS USED:   6239624
== TAVERN balances after claims
== done: outputs in /home/user/Sealed/demo-out
```
