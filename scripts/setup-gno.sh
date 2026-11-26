#!/usr/bin/env bash
# Installs gno, gnokey and gnodev at the exact version Onyx runs, then seeds
# gno's package cache from that version's examples/ so `gno test` works
# offline (by default it downloads imports from rpc.gno.land).
#
# Usage: scripts/setup-gno.sh [workdir]   (default workdir: ~/gno-src)
set -euo pipefail

ONYX_VERSION="v1.8.0-rc.1" # see misc/deployments/onyx.gno.land/UPGRADES.md on chain/mainnet
WORK="${1:-$HOME/gno-src}"
SRC="$WORK/gno-$ONYX_VERSION"

if [ ! -d "$SRC" ]; then
  mkdir -p "$WORK"
  git clone --depth 1 -b "$ONYX_VERSION" https://github.com/gnolang/gno.git "$SRC"
fi

if ! command -v gnodev >/dev/null 2>&1 || [ "${FORCE_INSTALL:-0}" = 1 ]; then
  make -C "$SRC" install
fi
# Put the tools on PATH when the Go bin dir isn't (needs a writable /usr/local/bin).
GOBIN_DIR="$(go env GOPATH)/bin"
if [ -w /usr/local/bin ]; then
  for t in gno gnokey gnodev; do ln -sf "$GOBIN_DIR/$t" "/usr/local/bin/$t"; done
fi
export PATH="$PATH:$GOBIN_DIR"

# Seed $GNOHOME/pkg/mod with every package under examples/gno.land, plus the
# marker files the loader checks before it tries to download.
mkdir -p "$SRC/misc/sealed-seedcache"
cat > "$SRC/misc/sealed-seedcache/main.go" <<'EOF'
package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/gnolang/gno/gnovm/pkg/gnolang"
	"github.com/gnolang/gno/gnovm/pkg/gnomod"
)

func main() {
	examples, _ := filepath.Abs("examples")
	cache := gnomod.ModCachePath()
	markers := filepath.Join(cache, ".markers")
	must(os.MkdirAll(markers, 0o755))
	n := 0
	must(filepath.WalkDir(examples, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || d.Name() != "gnomod.toml" {
			return err
		}
		dir := filepath.Dir(p)
		pkgPath := filepath.ToSlash(strings.TrimPrefix(dir, examples+string(os.PathSeparator)))
		dst := filepath.Join(cache, filepath.FromSlash(pkgPath))
		must(os.MkdirAll(dst, 0o755))
		entries, _ := os.ReadDir(dir)
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			b, err := os.ReadFile(filepath.Join(dir, e.Name()))
			must(err)
			must(os.WriteFile(filepath.Join(dst, e.Name()), b, 0o644))
		}
		must(os.WriteFile(filepath.Join(markers, gnolang.DerivePkgBech32Addr(pkgPath).String()), nil, 0o644))
		n++
		return nil
	}))
	fmt.Printf("seeded %d packages into %s\n", n, cache)
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
EOF
(cd "$SRC" && go run ./misc/sealed-seedcache)

echo "gno version: $(gno version)"
echo "Done. Run tests with: gno test ./realms/..."
