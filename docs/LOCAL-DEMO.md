# SEALED: local demo transcript

Produced by `scripts/demo-local.sh` on a local gnodev chain (Gno `v1.8.0`,
the Onyx version). Six throwaway accounts: one seller and five bidders.
Every step is a real signed transaction (`gnokey maketx call`). The pages
below are the realm's `Render()` output, captured with
`gnokey query vm/qrender` after each phase.

Setup: 1,000 TAVERN for sale, reserve price 1 GNOT, commit window 45 s,
reveal window 40 s.

| Bidder | Sealed bid | Deposit | Reveals? |
|---|---|---:|---|
| alice | 3 GNOT × 300 | 1,000 GNOT (over-deposit hides her size) | yes |
| bob | 2.5 GNOT × 250 | 625 GNOT | yes |
| carol | 2 GNOT × 400 | 800 GNOT | yes |
| dave | 2 GNOT × 200 | 400 GNOT | yes |
| erin | 4 GNOT × 500 | 2,000 GNOT | **no** (sniper no-show) |

Accounts:

```
sealed realm: gno.land/r/dev/sealed (g1jfk0kh44l5jsrr3d7ugfflxfnfxchnvq8qv0me)
seller: g1cvqk8cnjm0vuzwdkfrp053v6kaaq7tv9he7eku
alice: g1dd4gder40570lm6pzr3vg6xax4wqlp3782cduz
bob: g1fgwks5n0vwqvxe9sgrp237t064nxme5ryhf9pa
carol: g14nhazv3tjquy3fsc82f0ttdlsvxc42wawsgvw2
dave: g18jnq9guqnc8xw0tcakrkvlxqp9gletlevkad6d
erin: g1ltkryku5vv348mn8drv05uynf00ykud0xjm3lt
```

> Note on "time left": gnodev page queries read the time of the last block
> that included transactions, so the countdown only moves when a tx lands.
> Deadlines are enforced with real block time: reveals before the commit end
> and settles before the reveal end are rejected (see the tests).

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
| [#1](/r/dev/sealed:auction/1) | TAVERN | 1,000 | 1 GNOT | 🔒 Commit | 45s | 0 |

---

**Launch a token:** approve `g1jfk0kh44l5jsrr3d7ugfflxfnfxchnvq8qv0me` on your GRC20 for the sale supply, then call `CreateAuction`.
```

```markdown
# Auction #1: 1,000 TAVERN

[← All auctions](/r/dev/sealed)

**🔒 Commit** · 45s left

- **Token:** `gno.land/r/dev/tavern.TAVERN`
- **Seller:** `g1cvqk8c…7eku`
- **Supply:** 1,000 TAVERN
- **Reserve price:** 1 GNOT per TAVERN
- **Commit ends:** 2026-11-25 18:08:42 UTC
- **Reveal ends:** 2026-11-25 18:09:22 UTC

## 🔒 0 sealed bids

Bid contents stay hidden. Only the count is public.

**To bid:** compute `sha256(yourAddress|price|amount|salt)` on your own machine, then call `Commit(1, <hash>)` and send a GNOT deposit of at least price × amount (deposit more to hide your bid size; the extra is refunded).
```

## 2. After 5 sealed commits

Only the count is public. Prices, amounts and bidders' intentions stay hidden.

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
| [#1](/r/dev/sealed:auction/1) | TAVERN | 1,000 | 1 GNOT | 🔒 Commit | 45s | 5 |

---

**Launch a token:** approve `g1jfk0kh44l5jsrr3d7ugfflxfnfxchnvq8qv0me` on your GRC20 for the sale supply, then call `CreateAuction`.
```

```markdown
# Auction #1: 1,000 TAVERN

[← All auctions](/r/dev/sealed)

**🔒 Commit** · 45s left

- **Token:** `gno.land/r/dev/tavern.TAVERN`
- **Seller:** `g1cvqk8c…7eku`
- **Supply:** 1,000 TAVERN
- **Reserve price:** 1 GNOT per TAVERN
- **Commit ends:** 2026-11-25 18:08:42 UTC
- **Reveal ends:** 2026-11-25 18:09:22 UTC

## 🔒 5 sealed bids

Bid contents stay hidden. Only the count is public.

**To bid:** compute `sha256(yourAddress|price|amount|salt)` on your own machine, then call `Commit(1, <hash>)` and send a GNOT deposit of at least price × amount (deposit more to hide your bid size; the extra is refunded).
```

## 3. Reveal phase (4 of 5 revealed, erin never shows)

```markdown
# Auction #1: 1,000 TAVERN

[← All auctions](/r/dev/sealed)

**🔓 Reveal** · 37s left

- **Token:** `gno.land/r/dev/tavern.TAVERN`
- **Seller:** `g1cvqk8c…7eku`
- **Supply:** 1,000 TAVERN
- **Reserve price:** 1 GNOT per TAVERN
- **Commit ends:** 2026-11-25 18:08:42 UTC
- **Reveal ends:** 2026-11-25 18:09:22 UTC

## 🔓 Reveal phase

**4 of 5** sealed bids revealed.

Call `Reveal(1, price, amount, salt)` before the window closes. A bid that is never revealed loses 10% of its deposit.
```

## 4. Reveal window closed

```markdown
# Auction #1: 1,000 TAVERN

[← All auctions](/r/dev/sealed)

**⏳ Ready to settle**

- **Token:** `gno.land/r/dev/tavern.TAVERN`
- **Seller:** `g1cvqk8c…7eku`
- **Supply:** 1,000 TAVERN
- **Reserve price:** 1 GNOT per TAVERN
- **Commit ends:** 2026-11-25 18:08:42 UTC
- **Reveal ends:** 2026-11-25 18:09:22 UTC

## ⏳ Reveal closed

**4 of 5** sealed bids revealed. Anyone can now call `Settle(1)`.
```

## 5. Settled (bob, a bidder, pressed Settle, but anyone can)

```markdown
# Auction #1: 1,000 TAVERN

[← All auctions](/r/dev/sealed)

**✅ Settled**

- **Token:** `gno.land/r/dev/tavern.TAVERN`
- **Seller:** `g1cvqk8c…7eku`
- **Supply:** 1,000 TAVERN
- **Reserve price:** 1 GNOT per TAVERN
- **Commit ends:** 2026-11-25 18:08:42 UTC
- **Reveal ends:** 2026-11-25 18:09:22 UTC

## ✅ Results

| Clearing price | Sold | Total raised |
|---:|---:|---:|
| **2 GNOT** | 1,000 / 1,000 TAVERN | 2,000 GNOT |

Every winner pays **2 GNOT per TAVERN**, the lowest accepted bid, however high they bid and whenever they committed.

- **Seller proceeds:** 2,200 GNOT (unclaimed)
- **Forfeits from no-shows:** 200 GNOT
- **Unsold, back to seller:** 0 TAVERN

### Bids

| Bidder | Bid price | Wanted | Won | Pays | Refund | Result | Claimed |
|---|---:|---:|---:|---:|---:|---|:---:|
| `g1dd4gde…cduz` | 3 GNOT | 300 | 300 | 600 GNOT | 400 GNOT | 🏆 Won | — |
| `g1fgwks5…f9pa` | 2.5 GNOT | 250 | 250 | 500 GNOT | 125 GNOT | 🏆 Won | — |
| `g14nhazv…gvw2` | 2 GNOT | 400 | 300 | 600 GNOT | 200 GNOT | 🌗 Partial fill | — |
| `g18jnq9g…ad6d` | 2 GNOT | 200 | 150 | 300 GNOT | 100 GNOT | 🌗 Partial fill | — |
| `g1ltkryk…m3lt` | sealed | — | 0 | 0 GNOT | 1,800 GNOT | ⚠️ No reveal (-10%) | — |

Winners and refunds: call `Claim(1)`.
```

What happened: alice (3 GNOT) and bob (2.5 GNOT) fill completely, using 550
of the 1,000. Carol and dave tie at 2 GNOT, wanting 600 for the 450 left, so
they split pro-rata: carol 400×450/600 = 300 and dave 200×450/600 = 150.
The clearing price is the lowest filled bid, **2 GNOT, and everyone pays
it**: alice pays 600 GNOT, not 900. Erin's sealed 4 GNOT bid never counted.
She gets 1,800 back and forfeits 200 GNOT (10%) to the seller.

## 6. After everyone claimed

```markdown
# Auction #1: 1,000 TAVERN

[← All auctions](/r/dev/sealed)

**✅ Settled**

- **Token:** `gno.land/r/dev/tavern.TAVERN`
- **Seller:** `g1cvqk8c…7eku`
- **Supply:** 1,000 TAVERN
- **Reserve price:** 1 GNOT per TAVERN
- **Commit ends:** 2026-11-25 18:08:42 UTC
- **Reveal ends:** 2026-11-25 18:09:22 UTC

## ✅ Results

| Clearing price | Sold | Total raised |
|---:|---:|---:|
| **2 GNOT** | 1,000 / 1,000 TAVERN | 2,000 GNOT |

Every winner pays **2 GNOT per TAVERN**, the lowest accepted bid, however high they bid and whenever they committed.

- **Seller proceeds:** 2,200 GNOT (claimed ✓)
- **Forfeits from no-shows:** 200 GNOT
- **Unsold, back to seller:** 0 TAVERN

### Bids

| Bidder | Bid price | Wanted | Won | Pays | Refund | Result | Claimed |
|---|---:|---:|---:|---:|---:|---|:---:|
| `g1dd4gde…cduz` | 3 GNOT | 300 | 300 | 600 GNOT | 400 GNOT | 🏆 Won | ✓ |
| `g1fgwks5…f9pa` | 2.5 GNOT | 250 | 250 | 500 GNOT | 125 GNOT | 🏆 Won | ✓ |
| `g14nhazv…gvw2` | 2 GNOT | 400 | 300 | 600 GNOT | 200 GNOT | 🌗 Partial fill | ✓ |
| `g18jnq9g…ad6d` | 2 GNOT | 200 | 150 | 300 GNOT | 100 GNOT | 🌗 Partial fill | ✓ |
| `g1ltkryk…m3lt` | sealed | — | 0 | 0 GNOT | 1,800 GNOT | ⚠️ No reveal (-10%) | ✓ |

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
| [#1](/r/dev/sealed:auction/1) | TAVERN | 1,000 | 1 GNOT | ✅ Settled | — | 5 |

---

**Launch a token:** approve `g1jfk0kh44l5jsrr3d7ugfflxfnfxchnvq8qv0me` on your GRC20 for the sale supply, then call `CreateAuction`.
```

TAVERN balances after claims (the seller started with 10,000 from the faucet
and escrowed 1,000):

```
seller: (9000 int64)
alice: (300 int64)
bob: (250 int64)
carol: (300 int64)
dave: (150 int64)
erin: (0 int64)
sealed escrow: (0 int64)
```

The SEALED escrow is back to 0: every token and every ugnot was paid out.

## Transaction log

```
== starting gnodev
== seller: faucet + approve SEALED for 1,000 TAVERN
OK!
GAS USED:   4869853
OK!
GAS USED:   5168671
== seller: CreateAuction(1,000 TAVERN, reserve 1 GNOT)
(1 uint64)
OK!
GAS USED:   10149646
== alice: Commit(sealed hash 5a50e09d07d080e783ab04dc9a61b0f8a066a65048851b3b6632099d95d44668, deposit 1000 GNOT)
OK!
GAS USED:   7350940
== bob: Commit(sealed hash a8becc4f8e26eef33f37195143a0cedacdc56261ac2b358456c115b7252b8d17, deposit 625 GNOT)
OK!
GAS USED:   7312005
== carol: Commit(sealed hash c76a6a6a574fb7ac378d6ba8aebdd31ab19937a8e9e68ee447a11912171a05af, deposit 800 GNOT)
OK!
GAS USED:   7851535
== dave: Commit(sealed hash e7af6bfa615f9d5515ffea36f6bd133f31504b377ba4aa86df44ad1a79e1478d, deposit 400 GNOT)
OK!
GAS USED:   8433652
== erin: Commit(sealed hash 4766f9e0bc02c243976b5e94779af43c3d7080859940e740c7c5960bcd33f6b5, deposit 2000 GNOT)
OK!
GAS USED:   8361135
== waiting for the commit phase to end
== alice: Reveal(3000000, 300, salt)
OK!
GAS USED:   6796896
== bob: Reveal(2500000, 250, salt)
OK!
GAS USED:   6946338
== carol: Reveal(2000000, 400, salt)
OK!
GAS USED:   6795045
== dave: Reveal(2000000, 200, salt)
OK!
GAS USED:   6864080
== waiting for the reveal window to close
== bob (anyone): Settle
OK!
GAS USED:   8319096
== alice: Claim
OK!
GAS USED:   10525037
== bob: Claim
OK!
GAS USED:   11307859
== carol: Claim
OK!
GAS USED:   11689359
== dave: Claim
OK!
GAS USED:   12273213
== erin: Claim
OK!
GAS USED:   7148505
== seller: Claim
OK!
GAS USED:   5968369
== TAVERN balances after claims
== done: outputs in /home/user/Sealed/demo-out
```
