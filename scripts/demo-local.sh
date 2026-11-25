#!/usr/bin/env bash
# Full SEALED lifecycle on a throwaway local chain (gnodev):
#   seller gets TAVERN from the faucet and approves SEALED,
#   creates an auction (1,000 TAVERN, reserve 1 GNOT),
#   5 bidders commit sealed bids, 4 reveal (1 no-show),
#   a passer-by settles, everyone claims.
# The Render page is captured after each phase into $OUT/*.md.
#
# Usage: scripts/demo-local.sh            (needs gno, gnokey, gnodev on PATH)
# Env:   COMMIT_SECS / REVEAL_SECS        phase lengths (default 45 / 40)
#        OUT                              output dir (default ./demo-out)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/demo-out}"
KEYS="$OUT/keys"            # throwaway local keys, gitignored
COMMIT_SECS="${COMMIT_SECS:-45}"
REVEAL_SECS="${REVEAL_SECS:-40}"
RPC="127.0.0.1:26657"
CHAIN="dev"
SEALED="gno.land/r/dev/sealed"
TAVERN="gno.land/r/dev/tavern"
TOKEN_KEY="$TAVERN.TAVERN"
GNOT=1000000

rm -rf "$OUT" && mkdir -p "$KEYS"
log() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

# --- keys ---------------------------------------------------------------
NAMES=(seller alice bob carol dave erin)
declare -A ADDR
for n in "${NAMES[@]}"; do
  mnemonic=$(gnokey generate 2>/dev/null | tail -n1)
  printf '%s\n\n\n' "$mnemonic" | gnokey add --recover "$n" --home "$KEYS" -insecure-password-stdin -quiet >/dev/null
  ADDR[$n]=$(gnokey list --home "$KEYS" | grep -E "\. $n \(" | sed -E 's/.*addr: (g1[0-9a-z]+).*/\1/')
done

# --- chain --------------------------------------------------------------
log "starting gnodev"
gnodev local -home "$KEYS" -no-watch -empty-blocks -empty-blocks-interval 1 \
  -node-rpc-listener "$RPC" -web-listener 127.0.0.1:8888 \
  "$ROOT/realms/tavern" "$ROOT/realms/sealed" >"$OUT/gnodev.log" 2>&1 &
GNODEV_PID=$!
trap 'kill $GNODEV_PID 2>/dev/null || true' EXIT
for _ in $(seq 1 120); do
  gnokey query vm/qrender --data "$SEALED:" -remote "$RPC" >/dev/null 2>&1 && break
  sleep 1
done

call() { # call <key> <func> [send] -- args...
  local key="$1" fn="$2" send="$3"; shift 4
  local pkg="$SEALED"
  case "$fn" in tavern.*) pkg="$TAVERN"; fn="${fn#tavern.}";; esac
  local args=()
  for a in "$@"; do args+=(-args "$a"); done
  local sendflag=()
  [ -n "$send" ] && sendflag=(-send "$send")
  echo "" | gnokey maketx call -pkgpath "$pkg" -func "$fn" "${args[@]}" "${sendflag[@]}" \
    -gas-fee 1000000ugnot -gas-wanted 50000000 -broadcast -chainid "$CHAIN" -remote "$RPC" \
    -insecure-password-stdin -home "$KEYS" "$key" 2>&1 | tee "$OUT/last-tx.txt" | grep -E "^\(|OK!|GAS USED|Error|error|panic" || true
}
render() { # render <path> <outfile>
  gnokey query vm/qrender --data "$SEALED:$1" -remote "$RPC" | sed '1{/^height:/d}' | sed '1s/^data: //' >"$OUT/$2"
  echo "---- Render($1) -> $OUT/$2"; cat "$OUT/$2"
}
qeval() { gnokey query vm/qeval --data "$1" -remote "$RPC" | sed -n 's/^data: //p'; }
commitment() { printf '%s' "$1|$2|$3|$4" | sha256sum | cut -d' ' -f1; }
wait_until() { local t=$1; while [ "$(date +%s)" -lt "$t" ]; do sleep 1; done; sleep 3; }

SEALED_ADDR=$(qeval "$SEALED.Address()" | sed -E 's/.*"(g1[0-9a-z]+)".*/\1/')
{
  echo "sealed realm: $SEALED ($SEALED_ADDR)"
  for n in "${NAMES[@]}"; do echo "$n: ${ADDR[$n]}"; done
} | tee "$OUT/accounts.txt"

# --- 0. seller prepares the sale tokens ---------------------------------
log "seller: faucet + approve SEALED for 1,000 TAVERN"
call seller tavern.Faucet "" --
call seller tavern.Approve "" -- "$SEALED_ADDR" 1000

# --- 1. create ------------------------------------------------------------
NOW=$(date +%s)
COMMIT_END=$((NOW + COMMIT_SECS))
REVEAL_END=$((COMMIT_END + REVEAL_SECS))
log "seller: CreateAuction(1,000 TAVERN, reserve 1 GNOT)"
call seller CreateAuction "" -- "$TOKEN_KEY" 1000 $((1 * GNOT)) "$COMMIT_END" "$REVEAL_END"
ID=1
render "" 01-home-created.md
render "auction/$ID" 02-auction-created.md

# --- 2. commit ------------------------------------------------------------
# name price(ugnot) amount deposit(ugnot)
BIDS=(
  "alice 3000000 300 1000000000"   # 3 GNOT x 300, over-deposits 1,000 GNOT to hide her size
  "bob   2500000 250 625000000"    # 2.5 GNOT x 250
  "carol 2000000 400 800000000"    # 2 GNOT x 400
  "dave  2000000 200 400000000"    # 2 GNOT x 200 (ties with carol)
  "erin  4000000 500 2000000000"   # 4 GNOT x 500, a sniper who never reveals
)
declare -A SALT
for b in "${BIDS[@]}"; do
  read -r n price amount deposit <<<"$b"
  SALT[$n]=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
  h=$(commitment "${ADDR[$n]}" "$price" "$amount" "${SALT[$n]}")
  log "$n: Commit(sealed hash $h, deposit $((deposit / GNOT)) GNOT)"
  call "$n" Commit "${deposit}ugnot" -- "$ID" "$h"
done
render "" 03-home-commit.md
render "auction/$ID" 04-auction-commit.md

# --- 3. reveal ------------------------------------------------------------
log "waiting for the commit phase to end"
wait_until "$COMMIT_END"
for b in "${BIDS[@]}"; do
  read -r n price amount deposit <<<"$b"
  [ "$n" = erin ] && continue # the no-show
  log "$n: Reveal($price, $amount, salt)"
  call "$n" Reveal "" -- "$ID" "$price" "$amount" "${SALT[$n]}"
done
render "auction/$ID" 05-auction-reveal.md

# --- 4. settle ------------------------------------------------------------
log "waiting for the reveal window to close"
wait_until "$REVEAL_END"
render "auction/$ID" 06-auction-closed.md
log "bob (anyone): Settle"
call bob Settle "" -- "$ID"
render "auction/$ID" 07-auction-settled.md

# --- 5. claim -------------------------------------------------------------
for n in alice bob carol dave erin seller; do
  log "$n: Claim"
  call "$n" Claim "" -- "$ID"
done
render "auction/$ID" 08-auction-claimed.md
render "" 09-home-final.md

log "TAVERN balances after claims"
for n in seller alice bob carol dave erin; do
  echo "$n: $(qeval "$TAVERN.BalanceOf(\"${ADDR[$n]}\")")"
done | tee "$OUT/balances.txt"
echo "sealed escrow: $(qeval "$TAVERN.BalanceOf(\"$SEALED_ADDR\")")" | tee -a "$OUT/balances.txt"
log "done: outputs in $OUT"
