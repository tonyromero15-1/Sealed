import { describe, expect, it } from "vitest";
import { commitmentPreimage, makeCommitment, randomSalt } from "./commitment";

// Vectors produced by the realm itself, so the page and the chain provably
// agree. The same first vector is asserted on the Gno side in
// realms/sealed/sealed_test.gno (TestCommitmentMatchesWebVector).
const vectors = [
  {
    // Returned by the deployed realm on onyx-1:
    //   vm/qeval  gno.land/r/g15xk7…fj40/sealed/v1.MakeCommitment("g16cyx…dely", 500000, 4, "abcdefgh")
    name: "MakeCommitment on onyx-1",
    bidder: "g16cyxw8jdpj8wy2gqd0kr0v77x84fpjc673dely",
    price: 500000n,
    amount: 4n,
    salt: "abcdefgh",
    want: "2a8ad9487f426b3bdc54ac23fd033286c6f5f9910f1e598058bb67fd5faa69a5",
  },
  {
    // A real sealed bid from the live auction #1 (docs/LIVE-DEMO.md): stored
    // by Commit and accepted by Reveal, so the realm hashed these inputs to it.
    name: "bidder1's live commitment, auction #1",
    bidder: "g16cyxw8jdpj8wy2gqd0kr0v77x84fpjc673dely",
    price: 500000n,
    amount: 4n,
    salt: "cd9d0930ce318970c6dfe6a20dbc5924",
    want: "03eb59bd6e8655f1a93c240c01591aa709980f1eddcd5472248ea30b9337421d",
  },
];

describe("commitment", () => {
  for (const v of vectors) {
    it(`matches the realm: ${v.name}`, async () => {
      expect(await makeCommitment(v.bidder, v.price, v.amount, v.salt)).toBe(v.want);
    });
  }

  it("uses the realm's exact preimage format", () => {
    expect(commitmentPreimage("g16cyxw8jdpj8wy2gqd0kr0v77x84fpjc673dely", 1500000n, 12n, "saltsalt")).toBe(
      "g16cyxw8jdpj8wy2gqd0kr0v77x84fpjc673dely|1500000|12|saltsalt",
    );
  });

  it("rejects inputs the realm would reject on reveal", () => {
    const a = "g16cyxw8jdpj8wy2gqd0kr0v77x84fpjc673dely";
    expect(() => commitmentPreimage(a, 1n, 1n, "short")).toThrow(/salt/);
    expect(() => commitmentPreimage(a, 0n, 1n, "longenough")).toThrow(/positive/);
    expect(() => commitmentPreimage("not-an-address", 1n, 1n, "longenough")).toThrow(/address/);
  });

  it("makes 32-hex-char random salts", () => {
    const s = randomSalt();
    expect(s).toMatch(/^[0-9a-f]{32}$/);
    expect(randomSalt()).not.toBe(s);
  });
});
