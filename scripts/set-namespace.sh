#!/usr/bin/env bash
# Moves the realms from the local dev namespace (gno.land/r/dev/...) to
# another one. On Onyx that must be your own address namespace:
#
#   scripts/set-namespace.sh g1youraddress...
#
# Rewrites gnomod.toml module paths and every gno.land/r/dev/ (and /r/dev/
# link) reference under realms/. Run it again with "dev" to go back.
set -euo pipefail

NS="${1:?usage: $0 <namespace, e.g. your g1 address>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CUR=$(sed -n 's|^module = "gno.land/r/\([^/]*\)/sealed/.*"|\1|p' "$ROOT/realms/sealed/gnomod.toml")

if [ "$CUR" = "$NS" ]; then
  echo "already on namespace $NS"
  exit 0
fi

grep -rl --include='*.gno' --include='gnomod.toml' -e "/r/$CUR/" "$ROOT/realms" |
  xargs sed -i "s|/r/$CUR/|/r/$NS/|g"

echo "namespace: $CUR -> $NS"
grep -h '^module' "$ROOT"/realms/*/gnomod.toml
