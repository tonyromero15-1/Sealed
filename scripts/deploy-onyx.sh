#!/usr/bin/env bash
# Deploys TAVERN (demo token) then SEALED to onyx-1 at the paths in their
# gnomod.toml files (run scripts/set-namespace.sh <your g1 address> first).
#
#   scripts/deploy-onyx.sh <key-name> [gnokey-home]
#
# Only source files are uploaded: _test.gno files stay in the repo. They are
# not needed on chain and they nearly double the gas an approver must spend
# to enable the package.
#
# Env: REMOTE (default https://rpc.onyx.testnets.gno.land:443; in a sandbox
#      whose proxy gnokey can't use, run scripts/rpc-relay.py and set
#      REMOTE=http://127.0.0.1:26690)
set -euo pipefail

KEY="${1:?usage: $0 <key-name> [gnokey-home]}"
HOME_DIR="${2:-$HOME/.config/gno}"
REMOTE="${REMOTE:-https://rpc.onyx.testnets.gno.land:443}"
CHAIN=onyx-1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

modpath() { sed -n 's|^module = "\(.*\)"|\1|p' "$ROOT/realms/$1/gnomod.toml"; }

for pkg in tavern sealed; do
  path="$(modpath "$pkg")"
  case "$path" in gno.land/r/dev/*) echo "still on the dev namespace: run scripts/set-namespace.sh <g1 address>" >&2; exit 1;; esac
  mkdir -p "$STAGE/$pkg"
  find "$ROOT/realms/$pkg" -maxdepth 1 -type f \( -name '*.gno' -o -name 'gnomod.toml' \) ! -name '*_test.gno' \
    -exec cp {} "$STAGE/$pkg/" \;
  echo "== deploying $path ($(ls "$STAGE/$pkg" | tr '\n' ' '))"
  echo "" | gnokey maketx addpkg -pkgpath "$path" -pkgdir "$STAGE/$pkg" \
    -gas-fee 100000ugnot -gas-wanted 100000000 -max-deposit 10000000ugnot \
    -broadcast -chainid "$CHAIN" -remote "$REMOTE" \
    -insecure-password-stdin -home "$HOME_DIR" "$KEY" 2>&1 | tee "$STAGE/$pkg.out"
  grep -q "^OK!" "$STAGE/$pkg.out" || { echo "deploy of $path failed" >&2; exit 1; }
  sleep 6 # let the account sequence settle before the next tx
done

echo
echo "== status (a parked package answers package_parked until an approver enables it)"
for pkg in tavern sealed; do
  path="$(modpath "$pkg")"
  if out=$(gnokey query vm/qrender --data "$path:" -remote "$REMOTE" 2>&1) && ! grep -qi "parked" <<<"$out"; then
    echo "$path: LIVE"
  else
    echo "$path: $(grep -oiE 'package[_ ]parked[^"]*|parked[^"]*' <<<"$out" | head -1 || echo 'not live yet')"
  fi
done
