#!/usr/bin/env bash
# One small, real SEALED auction on onyx-1:
#   3 fresh testnet bidder keys funded from the deployer,
#   seller (deployer) creates 8 TAVERN at reserve 0.1 GNOT,
#   3 commits, 2 reveals (1 no-show), settle, all claims.
# Every tx (hash + height) goes to $OUT/txs.tsv, every page to $OUT/NN-*.md.
# Stops at the first tx that is not OK.
#
# Usage: scripts/demo-onyx.sh
# Env:   REMOTE     RPC (default https://rpc.onyx.testnets.gno.land:443;
#                   in a sandbox use scripts/rpc-relay.py -> http://127.0.0.1:26690)
#        SELLER_HOME / SELLER  deployer keybase + key name
#        BIDDER_HOME           keybase for the bidder keys (created if missing)
#        COMMIT_SECS / REVEAL_SECS  (default 600 / 600)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/demo-out-onyx}"
REMOTE="${REMOTE:-https://rpc.onyx.testnets.gno.land:443}"
CHAIN=onyx-1
SELLER_HOME="${SELLER_HOME:-$HOME/.sealed-deployer}"
SELLER="${SELLER:-sealed-deployer}"
BIDDER_HOME="${BIDDER_HOME:-$HOME/.sealed-bidders}"
COMMIT_SECS="${COMMIT_SECS:-600}"
REVEAL_SECS="${REVEAL_SECS:-600}"
FUND=5000000 # 5 GNOT per bidder

modpath() { sed -n 's|^module = "\(.*\)"|\1|p' "$ROOT/realms/$1/gnomod.toml"; }
SEALED="$(modpath sealed)"
TAVERN="$(modpath tavern)"
TOKEN_KEY="$TAVERN.TAVERN"

mkdir -p "$OUT" "$BIDDER_HOME"
chmod 700 "$BIDDER_HOME"
TXS="$OUT/txs.tsv"
: >"$TXS"
log() { printf '\n== %s  [%s]\n' "$*" "$(date -u +%T)"; }

addr_of() { gnokey list --home "$1" | grep -E "\. $2 \(" | sed -E 's/.*addr: (g1[0-9a-z]+).*/\1/'; }

BIDDERS=(bidder1 bidder2 bidder3)
declare -A ADDR HOMEOF
for b in "${BIDDERS[@]}"; do
  if [ -z "$(addr_of "$BIDDER_HOME" "$b")" ]; then
    printf '%s\n\n\n' "$(gnokey generate)" |
      gnokey add --recover "$b" --home "$BIDDER_HOME" -insecure-password-stdin -quiet >/dev/null 2>&1
  fi
  ADDR[$b]=$(addr_of "$BIDDER_HOME" "$b")
  HOMEOF[$b]="$BIDDER_HOME"
done
ADDR[seller]=$(addr_of "$SELLER_HOME" "$SELLER")
HOMEOF[seller]="$SELLER_HOME"

# record <label> <gnokey output file>
record() {
  local label="$1" f="$2" h64 hex height
  h64=$(sed -n 's/^TX HASH: *//p' "$f")
  height=$(sed -n 's/^HEIGHT: *//p' "$f")
  hex=$(printf '%s' "$h64" | base64 -d | od -An -tx1 | tr -d ' \n')
  printf '%s\t%s\t%s\n' "$label" "$height" "$hex" >>"$TXS"
  echo "   ok  height=$height  tx=$hex"
}

gk() { # gk <who> <label> -- gnokey maketx args...
  local who="$1" label="$2"; shift 3
  local key="$who"; [ "$who" = seller ] && key="$SELLER"
  local f="$OUT/tx-$(wc -l <"$TXS").txt"
  echo "" | gnokey maketx "$@" -gas-fee 100000ugnot -gas-wanted 50000000 -broadcast \
    -chainid "$CHAIN" -remote "$REMOTE" -insecure-password-stdin -home "${HOMEOF[$who]}" "$key" >"$f" 2>&1 || true
  if ! grep -q '^OK!' "$f"; then
    echo "!! $label FAILED:"; cat "$f"; exit 1
  fi
  record "$label" "$f"
  sleep 2
}
call() { # call <who> <label> <pkg> <func> [send] -- args...
  local who="$1" label="$2" pkg="$3" fn="$4" send="$5"; shift 6
  local args=() s=()
  for a in "$@"; do args+=(-args "$a"); done
  [ -n "$send" ] && s=(-send "$send")
  gk "$who" "$label" -- call -pkgpath "$pkg" -func "$fn" "${args[@]}" "${s[@]}"
}
render() { # render <path> <file>
  gnokey query vm/qrender --data "$SEALED:$1" -remote "$REMOTE" | sed '1{/^height:/d}' | sed '1s/^data: //' >"$OUT/$2"
  echo "   page saved: $2"
}
qeval() { gnokey query vm/qeval --data "$1" -remote "$REMOTE" | sed -n 's/^data: //p'; }
commitment() { printf '%s' "$1|$2|$3|$4" | sha256sum | cut -d' ' -f1; }
wait_until() { while [ "$(date +%s)" -lt "$1" ]; do sleep 5; done; sleep 10; }

SEALED_ADDR=$(qeval "$SEALED.Address()" | sed -E 's/.*"(g1[0-9a-z]+)".*/\1/')
{
  echo "sealed: $SEALED ($SEALED_ADDR)"
  for w in seller "${BIDDERS[@]}"; do echo "$w: ${ADDR[$w]}"; done
} | tee "$OUT/accounts.txt"

log "fund bidders (5 GNOT each, plain bank sends)"
for b in "${BIDDERS[@]}"; do
  gk seller "fund $b" -- send -to "${ADDR[$b]}" -send "${FUND}ugnot"
done

log "seller: TAVERN faucet + approve SEALED for 8"
call seller "tavern.Faucet" "$TAVERN" Faucet "" --
call seller "tavern.Approve" "$TAVERN" Approve "" -- "$SEALED_ADDR" 8

NOW=$(date +%s)
COMMIT_END=$((NOW + COMMIT_SECS))
REVEAL_END=$((COMMIT_END + REVEAL_SECS))
echo "$COMMIT_END $REVEAL_END" >"$OUT/windows.txt"
log "seller: CreateAuction(8 TAVERN, reserve 0.1 GNOT, commit until $(date -u -d @$COMMIT_END +%T), reveal until $(date -u -d @$REVEAL_END +%T))"
call seller "CreateAuction" "$SEALED" CreateAuction "" -- "$TOKEN_KEY" 8 100000 "$COMMIT_END" "$REVEAL_END"
ID=$(sed -n 's/^(\([0-9]*\) uint64)$/\1/p' "$OUT/tx-$(($(wc -l <"$TXS") - 1)).txt")
echo "$ID" >"$OUT/id.txt"
echo "   auction id: $ID"
render "" 01-home-created.md
render "auction/$ID" 02-auction-created.md

# name price(ugnot) amount deposit(ugnot)
BIDS=(
  "bidder1 500000 4 2500000" # 0.5 GNOT x 4 = 2 GNOT; deposits 2.5 to hide size
  "bidder2 300000 6 1800000" # 0.3 GNOT x 6 = 1.8 GNOT
  "bidder3 400000 5 2000000" # 0.4 GNOT x 5, never reveals
)
declare -A SALT
for line in "${BIDS[@]}"; do
  read -r n price amount deposit <<<"$line"
  SALT[$n]=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
  printf '%s %s\n' "$n" "${SALT[$n]}" >>"$BIDDER_HOME/salts-auction-$ID.txt" # outside the repo
  h=$(commitment "${ADDR[$n]}" "$price" "$amount" "${SALT[$n]}")
  log "$n: Commit (hash $h, deposit ${deposit}ugnot)"
  call "$n" "Commit $n" "$SEALED" Commit "${deposit}ugnot" -- "$ID" "$h"
done
render "" 03-home-commit.md
render "auction/$ID" 04-auction-commit.md

log "waiting for the commit phase to end"
wait_until "$COMMIT_END"
for line in "${BIDS[@]}"; do
  read -r n price amount deposit <<<"$line"
  [ "$n" = bidder3 ] && continue
  log "$n: Reveal($price, $amount)"
  call "$n" "Reveal $n" "$SEALED" Reveal "" -- "$ID" "$price" "$amount" "${SALT[$n]}"
done
render "auction/$ID" 05-auction-reveal.md

log "waiting for the reveal window to close"
wait_until "$REVEAL_END"
render "auction/$ID" 06-auction-closed.md
log "bidder3 (anyone, even the no-show): Settle"
call bidder3 "Settle" "$SEALED" Settle "" -- "$ID"
render "auction/$ID" 07-auction-settled.md

for w in bidder1 bidder2 bidder3 seller; do
  log "$w: Claim"
  call "$w" "Claim $w" "$SEALED" Claim "" -- "$ID"
done
render "auction/$ID" 08-auction-claimed.md
render "" 09-home-final.md

log "balances"
for w in seller "${BIDDERS[@]}"; do
  echo "$w: $(gnokey query bank/balances/${ADDR[$w]} -remote "$REMOTE" | sed -n 's/^data: //p') / TAVERN $(qeval "$TAVERN.BalanceOf(\"${ADDR[$w]}\")")"
done | tee "$OUT/balances.txt"
echo "sealed escrow TAVERN: $(qeval "$TAVERN.BalanceOf(\"$SEALED_ADDR\")")" | tee -a "$OUT/balances.txt"
log "DONE"
