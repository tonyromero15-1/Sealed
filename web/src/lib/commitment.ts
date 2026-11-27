// The commitment, byte for byte as the realm computes it in MakeCommitment:
//
//   hex(sha256(bidder.String() + "|" + price + "|" + amount + "|" + salt))
//
// price and amount are base-10 integers (ugnot per token unit, token units),
// with no separators. The salt never leaves the browser until Reveal.

export const MIN_SALT_LEN = 8;
export const MAX_SALT_LEN = 128;

export function commitmentPreimage(bidder: string, price: bigint, amount: bigint, salt: string): string {
  if (!/^g1[02-9ac-hj-np-z]{38}$/.test(bidder)) throw new Error("not a g1 address: " + bidder);
  if (price <= 0n || amount <= 0n) throw new Error("price and amount must be positive");
  if (salt.length < MIN_SALT_LEN || salt.length > MAX_SALT_LEN) {
    throw new Error(`salt must be ${MIN_SALT_LEN} to ${MAX_SALT_LEN} characters`);
  }
  return `${bidder}|${price.toString(10)}|${amount.toString(10)}|${salt}`;
}

export async function makeCommitment(bidder: string, price: bigint, amount: bigint, salt: string): Promise<string> {
  const bytes = new TextEncoder().encode(commitmentPreimage(bidder, price, amount, salt));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// 16 random bytes as 32 hex characters (the realm allows 8 to 128).
export function randomSalt(): string {
  const b = new Uint8Array(16);
  crypto.getRandomValues(b);
  return [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
}
