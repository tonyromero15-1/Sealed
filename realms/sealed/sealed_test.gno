package sealed

import (
	"chain"
	"chain/banker"
	"chain/runtime"
	"strings"
	"testing"
	"time"

	"gno.land/p/nt/grc20/v0"
	"gno.land/p/nt/testutils/v0"
	"gno.land/p/nt/uassert/v0"
	"gno.land/p/nt/urequire/v0"
	"gno.land/r/nt/grc20reg/v0"
)

// ---------------------------------------------------------------------------
// Test fixtures

const (
	gnot     int64 = 1_000_000 // ugnot
	testSalt       = "pepper-and-salt"
	// A throwaway token realm, so these tests depend on no other realm.
	testTokenRealm = "gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealedtesttoken"
)

var (
	tToken  *grc20.Token
	tLedger *grc20.PrivateLedger
	tKey    string
)

// In this gno version testing.SetRealm only takes effect when it is called
// in the test function body itself, so every test sets the signer inline
// (testing.SetRealm(u(addr))) and the helpers below never switch realms.

func u(addr address) runtime.Realm { return testing.NewUserRealm(addr) }

// ensureToken creates the test token once. Call it right after
// testing.SetRealm(testing.NewCodeRealm(testTokenRealm)).
func ensureToken(t *testing.T, rlm realm) {
	if tKey != "" {
		return
	}
	tToken, tLedger = grc20.NewToken("Sealed Test Token", "STEST", 0, 0, rlm)
	tKey = grc20reg.Register(cross(rlm), tToken, "")
}

// newAuction mints `supply` to the current signer (the seller), approves
// the realm, and opens an auction: commit ends in 100s, reveal in 200s.
func newAuction(t *testing.T, rlm realm, seller address, supply, reserve int64) uint64 {
	urequire.NoError(t, tLedger.Mint(seller, supply))
	urequire.NoError(t, tLedger.ImpersonateTeller(seller).Approve(0, rlm, realmAddr, supply))
	testing.SetOriginSend(nil)
	now := time.Now().Unix()
	return CreateAuction(cross(rlm), tKey, supply, reserve, now+100, now+200)
}

// send attaches `deposit` ugnot to the next call. gno test does not move
// coins for -send, so they are issued straight to the realm, which is what
// the chain does before it runs the call.
func send(deposit int64) {
	testing.SetOriginSend(chain.Coins{{Denom, deposit}})
	testing.IssueCoins(realmAddr, chain.Coins{{Denom, deposit}})
}

// commitBid: the current signer `who` seals (price, amount) with `deposit`.
func commitBid(t *testing.T, rlm realm, id uint64, who address, price, amount, deposit int64) {
	send(deposit)
	Commit(cross(rlm), id, MakeCommitment(who, price, amount, testSalt))
	testing.SetOriginSend(nil)
}

func revealBid(t *testing.T, rlm realm, id uint64, price, amount int64) {
	Reveal(cross(rlm), id, price, amount, testSalt)
}

// Phases: commit ends at +100s and reveal at +200s. SkipHeights moves block
// time 5s per block.
func toRevealPhase() { testing.SkipHeights(21) } // +105s
func toClosedPhase() { testing.SkipHeights(20) } // +100s more

func ugnotOf(addr address) int64 {
	return banker.NewReadonlyBanker().GetCoin(addr, Denom)
}

func user(name string) address { return testutils.TestAddress(name) }

func getAuction(id uint64) *Auction { return mustGetAuction(id) }

// ---------------------------------------------------------------------------
// Rejections

func TestRejectWrongSalt(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, alice := user("wrongsalt-seller"), user("wrongsalt-alice")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 1000, gnot)
	testing.SetRealm(u(alice))
	commitBid(t, cur, id, alice, 2*gnot, 100, 200*gnot)
	toRevealPhase()

	testing.SetRealm(u(alice))
	uassert.AbortsContains(t, cur, "does not match the commitment", func() {
		Reveal(cross(cur), id, 2*gnot, 100, "not-the-right-salt")
	})
	// The right salt with a different price is rejected too.
	uassert.AbortsContains(t, cur, "does not match the commitment", func() {
		Reveal(cross(cur), id, 1*gnot, 100, testSalt)
	})
	uassert.False(t, getAuction(id).getBid(alice).Revealed)
}

func TestRejectInsufficientDeposit(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, bob := user("lowdep-seller"), user("lowdep-bob")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 1000, gnot)
	// Bids 2 GNOT x 100 = 200 GNOT but deposits only 150 GNOT.
	testing.SetRealm(u(bob))
	commitBid(t, cur, id, bob, 2*gnot, 100, 150*gnot)
	toRevealPhase()

	testing.SetRealm(u(bob))
	uassert.AbortsContains(t, cur, "insufficient deposit", func() {
		Reveal(cross(cur), id, 2*gnot, 100, testSalt)
	})
	uassert.False(t, getAuction(id).getBid(bob).Revealed)
}

func TestRejectDoubleCommit(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, carol := user("double-seller"), user("double-carol")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 1000, gnot)
	testing.SetRealm(u(carol))
	commitBid(t, cur, id, carol, 2*gnot, 100, 200*gnot)

	testing.SetRealm(u(carol))
	send(300 * gnot)
	uassert.AbortsContains(t, cur, "already committed", func() {
		Commit(cross(cur), id, MakeCommitment(carol, 3*gnot, 100, testSalt))
	})
	uassert.Equal(t, 1, SealedBids(id))
}

func TestRejectRevealOutsideWindow(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, dave, erin := user("window-seller"), user("window-dave"), user("window-erin")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 1000, gnot)
	testing.SetRealm(u(dave))
	commitBid(t, cur, id, dave, 2*gnot, 100, 200*gnot)
	testing.SetRealm(u(erin))
	commitBid(t, cur, id, erin, 2*gnot, 100, 200*gnot)

	// Too early: the commit phase is still open.
	testing.SetRealm(u(dave))
	uassert.AbortsContains(t, cur, "too early to reveal", func() {
		Reveal(cross(cur), id, 2*gnot, 100, testSalt)
	})

	// Too late: the reveal window has closed.
	toRevealPhase()
	toClosedPhase()
	testing.SetRealm(u(erin))
	uassert.AbortsContains(t, cur, "reveal window has closed", func() {
		Reveal(cross(cur), id, 2*gnot, 100, testSalt)
	})
}

func TestRejectLateCommit(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, frank := user("late-seller"), user("late-frank")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 1000, gnot)
	toRevealPhase()
	testing.SetRealm(u(frank))
	send(100 * gnot)
	uassert.AbortsContains(t, cur, "commit phase is over", func() {
		Commit(cross(cur), id, MakeCommitment(frank, gnot, 10, testSalt))
	})
}

func TestRejectSettleTooEarly(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, gina := user("early-seller"), user("early-gina")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 1000, gnot)
	testing.SetRealm(u(gina))
	commitBid(t, cur, id, gina, 2*gnot, 100, 200*gnot)

	// During commit.
	uassert.AbortsContains(t, cur, "too early to settle", func() { Settle(cross(cur), id) })
	// During reveal. Claim cannot sneak past it either.
	toRevealPhase()
	testing.SetRealm(u(gina))
	uassert.AbortsContains(t, cur, "too early to settle", func() { Settle(cross(cur), id) })
	uassert.AbortsContains(t, cur, "too early to settle", func() { Claim(cross(cur), id) })

	revealBid(t, cur, id, 2*gnot, 100)
	toClosedPhase()
	testing.SetRealm(u(gina))
	Settle(cross(cur), id)
	uassert.AbortsContains(t, cur, "already settled", func() { Settle(cross(cur), id) })
}

func TestRejectBadCommits(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, hank := user("badcommit-seller"), user("badcommit-hank")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 1000, gnot)

	testing.SetRealm(u(hank))
	send(100 * gnot)
	uassert.AbortsContains(t, cur, "64 hex characters", func() { Commit(cross(cur), id, "abc") })

	send(MinDeposit - 1)
	uassert.AbortsContains(t, cur, "deposit must be at least", func() {
		Commit(cross(cur), id, MakeCommitment(hank, gnot, 1, testSalt))
	})

	// Only a direct user call may commit, since it reads the tx's coins.
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/middleman"))
	send(100 * gnot)
	uassert.AbortsContains(t, cur, "directly from a user account", func() {
		Commit(cross(cur), id, MakeCommitment(hank, gnot, 1, testSalt))
	})
	uassert.Equal(t, 0, SealedBids(id))
}

func TestCreateAuctionValidation(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller := user("validation-seller")
	urequire.NoError(t, tLedger.Mint(seller, 50))
	now := time.Now().Unix()

	testing.SetRealm(u(seller))
	uassert.AbortsContains(t, cur, "unknown token", func() {
		CreateAuction(cross(cur), "gno.land/r/nope.NOPE", 50, gnot, now+100, now+200)
	})
	uassert.AbortsContains(t, cur, "revealEnd must be after commitEnd", func() {
		CreateAuction(cross(cur), tKey, 50, gnot, now+100, now+100)
	})
	uassert.AbortsContains(t, cur, "commitEnd must be in the future", func() {
		CreateAuction(cross(cur), tKey, 50, gnot, now, now+100)
	})
	uassert.AbortsContains(t, cur, "approve", func() { // no allowance yet
		CreateAuction(cross(cur), tKey, 50, gnot, now+100, now+200)
	})
	uassert.Equal(t, int64(50), tToken.BalanceOf(seller))
}

// ---------------------------------------------------------------------------
// Auction math

// 1,000 tokens, three bidders. Everyone who wins pays 1.5 GNOT, the lowest
// filled bid, not their own price. The lowest bidder is filled partially.
func TestUniformClearingPriceAndPartialFill(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller := user("uniform-seller")
	ann, ben, cat := user("uniform-ann"), user("uniform-ben"), user("uniform-cat")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 1000, gnot)
	testing.SetRealm(u(ann))
	commitBid(t, cur, id, ann, 3*gnot, 400, 1200*gnot)
	testing.SetRealm(u(ben))
	commitBid(t, cur, id, ben, 2*gnot, 300, 600*gnot)
	testing.SetRealm(u(cat))
	commitBid(t, cur, id, cat, 1_500_000, 500, 750*gnot)

	toRevealPhase()
	testing.SetRealm(u(ann))
	revealBid(t, cur, id, 3*gnot, 400)
	testing.SetRealm(u(ben))
	revealBid(t, cur, id, 2*gnot, 300)
	testing.SetRealm(u(cat))
	revealBid(t, cur, id, 1_500_000, 500)

	toClosedPhase()
	testing.SetRealm(u(user("passer-by"))) // anyone can settle
	Settle(cross(cur), id)

	a := getAuction(id)
	uassert.Equal(t, int64(1_500_000), a.clearingPrice)
	uassert.Equal(t, int64(1000), a.sold)
	uassert.Equal(t, 1500*gnot, a.raised)

	oa := a.outcomeOf(a.getBid(ann))
	ob := a.outcomeOf(a.getBid(ben))
	oc := a.outcomeOf(a.getBid(cat))
	uassert.Equal(t, int64(400), oa.Filled)
	uassert.Equal(t, 600*gnot, oa.Cost) // 400 x 1.5, not 400 x 3
	uassert.Equal(t, 600*gnot, oa.Refund)
	uassert.Equal(t, int64(300), ob.Filled)
	uassert.Equal(t, 450*gnot, ob.Cost)
	uassert.Equal(t, 150*gnot, ob.Refund)
	// Cat is the marginal bid: only 300 of the 500 wanted are left.
	uassert.Equal(t, int64(300), oc.Filled)
	uassert.Equal(t, "Partial fill", oc.Status)
	uassert.Equal(t, 450*gnot, oc.Cost)
	uassert.Equal(t, 300*gnot, oc.Refund)
}

// Two bids tie at the clearing price and split what is left pro-rata.
// Commit order and reveal order change nothing: no time priority.
func TestProRataTieAtClearingPrice(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller := user("tie-seller")
	top, early, late := user("tie-top"), user("tie-early"), user("tie-late")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 100, gnot)
	testing.SetRealm(u(early))
	commitBid(t, cur, id, early, gnot, 90, 90*gnot)
	testing.SetRealm(u(top))
	commitBid(t, cur, id, top, 2*gnot, 40, 80*gnot)
	testing.SetRealm(u(late))
	commitBid(t, cur, id, late, gnot, 60, 60*gnot)

	toRevealPhase()
	testing.SetRealm(u(late))
	revealBid(t, cur, id, gnot, 60)
	testing.SetRealm(u(top))
	revealBid(t, cur, id, 2*gnot, 40)
	testing.SetRealm(u(early))
	revealBid(t, cur, id, gnot, 90)

	toClosedPhase()
	testing.SetRealm(u(top))
	Settle(cross(cur), id)

	a := getAuction(id)
	uassert.Equal(t, gnot, a.clearingPrice)
	uassert.Equal(t, int64(40), a.fillOf(a.getBid(top)))
	// 60 tokens left for 150 wanted at 1 GNOT: 90*60/150 = 36 and 60*60/150 = 24.
	uassert.Equal(t, int64(36), a.fillOf(a.getBid(early)))
	uassert.Equal(t, int64(24), a.fillOf(a.getBid(late)))
	uassert.Equal(t, int64(100), a.sold)
	// The top bidder bid 2 GNOT but pays the 1 GNOT clearing price.
	uassert.Equal(t, 40*gnot, a.outcomeOf(a.getBid(top)).Cost)
}

// Rounding dust from a pro-rata split is never handed out by order; it goes
// back to the seller.
func TestProRataDustReturnsToSeller(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller := user("dust-seller")
	b1, b2, b3 := user("dust-1"), user("dust-2"), user("dust-3")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 10, gnot)
	testing.SetRealm(u(b1))
	commitBid(t, cur, id, b1, gnot, 10, 10*gnot)
	testing.SetRealm(u(b2))
	commitBid(t, cur, id, b2, gnot, 10, 10*gnot)
	testing.SetRealm(u(b3))
	commitBid(t, cur, id, b3, gnot, 10, 10*gnot)
	toRevealPhase()
	testing.SetRealm(u(b1))
	revealBid(t, cur, id, gnot, 10)
	testing.SetRealm(u(b2))
	revealBid(t, cur, id, gnot, 10)
	testing.SetRealm(u(b3))
	revealBid(t, cur, id, gnot, 10)
	toClosedPhase()
	testing.SetRealm(u(seller))
	Claim(cross(cur), id) // settles, then pays the seller

	a := getAuction(id)
	uassert.Equal(t, int64(3), a.fillOf(a.getBid(b1)))
	uassert.Equal(t, int64(3), a.fillOf(a.getBid(b2)))
	uassert.Equal(t, int64(3), a.fillOf(a.getBid(b3)))
	uassert.Equal(t, int64(9), a.sold)
	uassert.Equal(t, int64(1), tToken.BalanceOf(seller))
}

func TestReservePrice(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, low, ok := user("reserve-seller"), user("reserve-low"), user("reserve-ok")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 100, gnot)
	testing.SetRealm(u(low))
	commitBid(t, cur, id, low, 500_000, 100, 50*gnot) // 0.5 GNOT, under the 1 GNOT reserve
	testing.SetRealm(u(ok))
	commitBid(t, cur, id, ok, gnot, 50, 50*gnot) // exactly the reserve
	toRevealPhase()
	testing.SetRealm(u(low))
	revealBid(t, cur, id, 500_000, 100)
	testing.SetRealm(u(ok))
	revealBid(t, cur, id, gnot, 50)
	toClosedPhase()
	testing.SetRealm(u(ok))
	Settle(cross(cur), id)

	a := getAuction(id)
	lowOut := a.outcomeOf(a.getBid(low))
	uassert.Equal(t, int64(0), lowOut.Filled)
	uassert.Equal(t, "Below reserve", lowOut.Status)
	uassert.Equal(t, 50*gnot, lowOut.Refund)
	uassert.Equal(t, int64(50), a.fillOf(a.getBid(ok)))
	uassert.Equal(t, gnot, a.clearingPrice)
	uassert.Equal(t, int64(50), a.sold)
}

func TestNothingAboveReserve(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, b := user("allbelow-seller"), user("allbelow-bidder")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 100, 5*gnot)
	testing.SetRealm(u(b))
	commitBid(t, cur, id, b, gnot, 100, 100*gnot)
	toRevealPhase()
	testing.SetRealm(u(b))
	revealBid(t, cur, id, gnot, 100)
	toClosedPhase()
	testing.SetRealm(u(b))
	Claim(cross(cur), id)

	a := getAuction(id)
	uassert.Equal(t, int64(0), a.clearingPrice)
	uassert.Equal(t, int64(0), a.sold)
	uassert.Equal(t, 100*gnot, ugnotOf(b)) // full refund
	testing.SetRealm(u(seller))
	Claim(cross(cur), id)
	uassert.Equal(t, int64(100), tToken.BalanceOf(seller)) // every token back
	uassert.Equal(t, int64(0), ugnotOf(seller))
}

func TestUnrevealedForfeitsTenPercent(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, shown, ghost := user("noshow-seller"), user("noshow-shown"), user("noshow-ghost")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 100, gnot)
	testing.SetRealm(u(shown))
	commitBid(t, cur, id, shown, gnot, 100, 100*gnot)
	testing.SetRealm(u(ghost))
	commitBid(t, cur, id, ghost, 3*gnot, 100, 300*gnot) // never reveals
	toRevealPhase()
	testing.SetRealm(u(shown))
	revealBid(t, cur, id, gnot, 100)
	toClosedPhase()
	testing.SetRealm(u(shown))
	Settle(cross(cur), id)

	a := getAuction(id)
	g := a.outcomeOf(a.getBid(ghost))
	uassert.Equal(t, int64(0), g.Filled)
	uassert.Equal(t, 30*gnot, g.Forfeit)
	uassert.Equal(t, 270*gnot, g.Refund)
	uassert.Equal(t, 30*gnot, a.forfeits)
	// The ghost's high sealed price never counted.
	uassert.Equal(t, gnot, a.clearingPrice)

	testing.SetRealm(u(ghost))
	Claim(cross(cur), id)
	uassert.Equal(t, 270*gnot, ugnotOf(ghost))
	// The only winner gets the whole forfeit; the seller gets none of it.
	testing.SetRealm(u(shown))
	Claim(cross(cur), id)
	uassert.Equal(t, 30*gnot, ugnotOf(shown)) // refund 0 + forfeit share 30
	testing.SetRealm(u(seller))
	Claim(cross(cur), id)
	uassert.Equal(t, 100*gnot, ugnotOf(seller)) // proceeds only
}

// A seller who sprays fake sealed bids from other addresses (to fake demand)
// and never reveals them gains nothing: the forfeit goes to the honest
// winner, and the seller's own side is strictly poorer.
func TestSellerFakeNoShowGainsNothing(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller := user("fake-seller")
	fake := user("fake-seller-sybil") // controlled by the seller
	honest := user("fake-honest")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 100, gnot)
	testing.SetRealm(u(honest))
	commitBid(t, cur, id, honest, gnot, 100, 100*gnot)
	testing.SetRealm(u(fake))
	commitBid(t, cur, id, fake, 5*gnot, 100, 200*gnot) // looks like strong demand
	uassert.Equal(t, 2, SealedBids(id))
	toRevealPhase()
	testing.SetRealm(u(honest))
	revealBid(t, cur, id, gnot, 100)
	toClosedPhase()

	testing.SetRealm(u(seller))
	Claim(cross(cur), id)
	testing.SetRealm(u(fake))
	Claim(cross(cur), id)
	testing.SetRealm(u(honest))
	Claim(cross(cur), id)

	a := getAuction(id)
	uassert.Equal(t, 100*gnot, a.raised)
	// Seller receives exactly the sale proceeds, nothing from the forfeit.
	uassert.Equal(t, 100*gnot, ugnotOf(seller))
	// Seller + sybil together: 100 + 180 = 280 GNOT, versus 300 GNOT
	// (proceeds + the sybil's own deposit) had they not faked the bid.
	uassert.Equal(t, 180*gnot, ugnotOf(fake))
	uassert.Equal(t, 280*gnot, ugnotOf(seller)+ugnotOf(fake))
	// The honest winner collects the 20 GNOT forfeit.
	uassert.Equal(t, int64(100), tToken.BalanceOf(honest))
	uassert.Equal(t, 20*gnot, ugnotOf(honest))
	uassert.Equal(t, int64(0), a.burned)
}

// Forfeits are split among winners by tokens won. Outbid and below-reserve
// bidders get none, and rounding dust is burned rather than handed out.
func TestForfeitSplitAmongWinners(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller := user("split-seller")
	a1, a2, a3 := user("split-a1"), user("split-a2"), user("split-a3")
	outbid, low, ghost := user("split-outbid"), user("split-low"), user("split-ghost")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 90, gnot)
	testing.SetRealm(u(a1))
	commitBid(t, cur, id, a1, 3*gnot, 30, 90*gnot)
	testing.SetRealm(u(a2))
	commitBid(t, cur, id, a2, 2*gnot, 30, 60*gnot)
	testing.SetRealm(u(a3))
	commitBid(t, cur, id, a3, 1_500_000, 30, 45*gnot)
	testing.SetRealm(u(outbid))
	commitBid(t, cur, id, outbid, 1_200_000, 30, 36*gnot)
	testing.SetRealm(u(low))
	commitBid(t, cur, id, low, 500_000, 10, 5*gnot)
	testing.SetRealm(u(ghost))
	commitBid(t, cur, id, ghost, 9*gnot, 1, 1_000_010) // forfeit = 100,001 ugnot
	toRevealPhase()
	testing.SetRealm(u(a1))
	revealBid(t, cur, id, 3*gnot, 30)
	testing.SetRealm(u(a2))
	revealBid(t, cur, id, 2*gnot, 30)
	testing.SetRealm(u(a3))
	revealBid(t, cur, id, 1_500_000, 30)
	testing.SetRealm(u(outbid))
	revealBid(t, cur, id, 1_200_000, 30)
	testing.SetRealm(u(low))
	revealBid(t, cur, id, 500_000, 10)
	toClosedPhase()
	testing.SetRealm(u(seller))
	Settle(cross(cur), id)

	a := getAuction(id)
	uassert.Equal(t, int64(1_500_000), a.clearingPrice)
	uassert.Equal(t, int64(90), a.sold)
	uassert.Equal(t, int64(100_001), a.forfeits)
	// Three equal winners: 100,001 * 30/90 = 33,333 each; 2 ugnot of dust burned.
	for _, w := range []address{a1, a2, a3} {
		uassert.Equal(t, int64(33_333), a.outcomeOf(a.getBid(w)).ForfeitShare)
	}
	uassert.Equal(t, int64(0), a.outcomeOf(a.getBid(outbid)).ForfeitShare)
	uassert.Equal(t, int64(0), a.outcomeOf(a.getBid(low)).ForfeitShare)
	uassert.Equal(t, int64(2), a.burned)

	// Claims pay exactly that: a1 deposited 90, pays 30 x 1.5 = 45.
	testing.SetRealm(u(a1))
	Claim(cross(cur), id)
	uassert.Equal(t, 45*gnot+33_333, ugnotOf(a1))
	testing.SetRealm(u(outbid))
	Claim(cross(cur), id)
	uassert.Equal(t, 36*gnot, ugnotOf(outbid)) // full refund, no share
	testing.SetRealm(u(seller))
	Claim(cross(cur), id)
	uassert.Equal(t, 135*gnot, ugnotOf(seller)) // 90 x 1.5 GNOT only
}

// If nobody wins, the forfeits are burned: kept by the realm forever and
// claimable by no one. The seller still gets nothing but their tokens back.
func TestNoWinnersForfeitsBurned(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, g1, g2 := user("burn-seller"), user("burn-ghost1"), user("burn-ghost2")
	gnotBefore := ugnotOf(realmAddr)

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 100, gnot)
	testing.SetRealm(u(g1))
	commitBid(t, cur, id, g1, 2*gnot, 50, 100*gnot)
	testing.SetRealm(u(g2))
	commitBid(t, cur, id, g2, 3*gnot, 50, 150*gnot)
	toRevealPhase()
	toClosedPhase() // nobody revealed
	testing.SetRealm(u(seller))
	Claim(cross(cur), id)

	a := getAuction(id)
	uassert.Equal(t, int64(0), a.sold)
	uassert.Equal(t, 25*gnot, a.forfeits)
	uassert.Equal(t, 25*gnot, a.burned)
	uassert.Equal(t, int64(0), ugnotOf(seller))
	uassert.Equal(t, int64(100), tToken.BalanceOf(seller))

	testing.SetRealm(u(g1))
	Claim(cross(cur), id)
	testing.SetRealm(u(g2))
	Claim(cross(cur), id)
	uassert.Equal(t, 90*gnot, ugnotOf(g1))
	uassert.Equal(t, 135*gnot, ugnotOf(g2))
	// Only the burned forfeits remain in the realm, and nobody can claim them.
	uassert.Equal(t, gnotBefore+25*gnot, ugnotOf(realmAddr))
	testing.SetRealm(u(seller))
	uassert.AbortsContains(t, cur, "nothing to claim", func() { Claim(cross(cur), id) })
}

// End to end: real token and GNOT balances after every claim, unsold tokens
// back to the seller, and nothing left to claim afterwards.
func TestClaimAmountsAndUnsoldReturned(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller := user("claims-seller")
	ivy, jon, kim := user("claims-ivy"), user("claims-jon"), user("claims-kim")
	escrowBefore := tToken.BalanceOf(realmAddr)
	gnotBefore := ugnotOf(realmAddr)

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 1000, gnot)
	uassert.Equal(t, escrowBefore+1000, tToken.BalanceOf(realmAddr)) // escrowed
	testing.SetRealm(u(ivy))
	commitBid(t, cur, id, ivy, 3*gnot, 200, 700*gnot) // over-deposits to hide her size
	testing.SetRealm(u(jon))
	commitBid(t, cur, id, jon, 2*gnot, 100, 200*gnot)
	testing.SetRealm(u(kim))
	commitBid(t, cur, id, kim, 2*gnot, 50, 120*gnot) // never reveals
	toRevealPhase()
	testing.SetRealm(u(ivy))
	revealBid(t, cur, id, 3*gnot, 200)
	testing.SetRealm(u(jon))
	revealBid(t, cur, id, 2*gnot, 100)
	toClosedPhase()

	// Claim settles automatically if nobody called Settle yet.
	testing.SetRealm(u(ivy))
	Claim(cross(cur), id)
	a := getAuction(id)
	uassert.True(t, a.settled)
	// Demand (300) < supply (1000): all fill, clearing = lowest bid = 2 GNOT.
	uassert.Equal(t, 2*gnot, a.clearingPrice)
	// Kim's 12 GNOT forfeit is split by tokens won: ivy 200/300, jon 100/300.
	uassert.Equal(t, int64(200), tToken.BalanceOf(ivy))
	uassert.Equal(t, (700-400+8)*gnot, ugnotOf(ivy))

	testing.SetRealm(u(jon))
	Claim(cross(cur), id)
	uassert.Equal(t, int64(100), tToken.BalanceOf(jon))
	uassert.Equal(t, 4*gnot, ugnotOf(jon)) // deposit covered the cost exactly; +4 GNOT forfeit share

	testing.SetRealm(u(kim))
	Claim(cross(cur), id)
	uassert.Equal(t, int64(0), tToken.BalanceOf(kim))
	uassert.Equal(t, 108*gnot, ugnotOf(kim)) // 120 - 10%

	testing.SetRealm(u(seller))
	Claim(cross(cur), id)
	uassert.Equal(t, int64(700), tToken.BalanceOf(seller)) // unsold returned
	uassert.Equal(t, 600*gnot, ugnotOf(seller))            // 300 x 2 GNOT, no forfeit

	// Every token and ugnot of this auction has left escrow.
	uassert.Equal(t, escrowBefore, tToken.BalanceOf(realmAddr))
	uassert.Equal(t, gnotBefore, ugnotOf(realmAddr))

	testing.SetRealm(u(ivy))
	uassert.AbortsContains(t, cur, "nothing to claim", func() { Claim(cross(cur), id) })
	testing.SetRealm(u(user("claims-stranger")))
	uassert.AbortsContains(t, cur, "nothing to claim", func() { Claim(cross(cur), id) })
}

// ---------------------------------------------------------------------------
// Pages

func TestRenderNeverLeaksSealedBids(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm(testTokenRealm))
	ensureToken(t, cur)
	seller, lea := user("render-seller"), user("render-lea")

	testing.SetRealm(u(seller))
	id := newAuction(t, cur, seller, 1000, gnot)
	testing.SetRealm(u(lea))
	commitBid(t, cur, id, lea, 7_777_777, 123, 1000*gnot)
	path := "auction/" + idStr(getAuction(id))

	page := Render(path)
	uassert.True(t, strings.Contains(page, "1 sealed bid"), page)
	uassert.False(t, strings.Contains(page, "7.777777"), "price leaked")
	uassert.False(t, strings.Contains(page, "123"), "amount leaked")
	uassert.True(t, strings.Contains(Render(""), "[#"+idStr(getAuction(id))+"]"))

	toRevealPhase()
	testing.SetRealm(u(lea))
	revealBid(t, cur, id, 7_777_777, 123)
	toClosedPhase()
	testing.SetRealm(u(lea))
	Settle(cross(cur), id)
	page = Render(path)
	uassert.True(t, strings.Contains(page, "7.777777 GNOT"), page)
	uassert.True(t, strings.Contains(page, "Results"), page)
}

func TestFormatting(t *testing.T) {
	uassert.Equal(t, "1,234,567", formatInt(1234567))
	uassert.Equal(t, "999", formatInt(999))
	uassert.Equal(t, "1.5 GNOT", formatGNOT(1_500_000))
	uassert.Equal(t, "0.000001 GNOT", formatGNOT(1))
	uassert.Equal(t, "1,200 GNOT", formatGNOT(1200*gnot))
	uassert.Equal(t, "2m 5s", formatDuration(125))
	uassert.Equal(t, int64(10), forfeitOf(100))
	uassert.Equal(t, int64(9), forfeitOf(99))
}
