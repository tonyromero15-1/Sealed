# Deployments

## onyx-1 (2026-11-26)

Deployer: `g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40` (testnet-only key)
Source: commit `9f07bf4`, uploaded with `scripts/deploy-onyx.sh` (source files
only, no `_test.gno`).

| Package | Height | Tx hash (hex) | Status |
|---|---:|---|---|
| `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1` | 1,435,523 | `ad847bdebfa818eafecdc553254eb7fd47930b97c2af8ffe498fa86d36641558` | **live** |
| `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1` | 1,435,526 | `f354739e4688f85eafc28ef4e9ee1406a075176ada9875776cb939c790fd5961` | **live** |

The same hashes in base64, as gnokey prints them:
`rYR73r+oGOr+zcVTJU63/UeTC5fCr4/+SY+obTZkFVg=` (tavern) and
`81RznkaI+F6vwo706e4UBqB1F2ramHV3bLk5x5D9WWE=` (sealed).

Each submission cost 0.1 GNOT in gas. Both were parked (inert) at first and
were **enabled by an approver by 2026-11-27**. The storage deposit was taken
then: 5.81 GNOT for both (balance 299.8 → 293.99 GNOT).

Live pages:
- https://onyx.testnets.gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1
- https://onyx.testnets.gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1

SEALED realm address (sellers approve this on their token):
`g19ewgjgpz7duvzr7w9wk356yclhu40gs00wr6wl`.
Token key for `CreateAuction`:
`gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1.TAVERN`.

When deployed, 162 packages were parked on Onyx (`vm/qinertpaths`).

### Check status

```sh
gnokey query vm/qpkgmeta_json --data "gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1" \
  -remote https://rpc.onyx.testnets.gno.land:443
# "status":"live"                        -> enabled
# "status":"inert" ... "pending":true    -> still parked
# Live pages render at:
#   https://onyx.testnets.gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1
```

These paths are now fixed. Fixes ship as `v2` next to them (and need a new
approval, so deploy early).
