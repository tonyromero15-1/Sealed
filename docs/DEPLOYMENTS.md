# Deployments

## onyx-1 (2026-11-26)

Deployer: `g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40` (testnet-only key)
Source: commit `9f07bf4`, uploaded with `scripts/deploy-onyx.sh` (source files
only, no `_test.gno`).

| Package | Height | Tx hash (hex) | Status |
|---|---:|---|---|
| `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/tavern/v1` | 1,435,523 | `ad847bdebfa818eafecdc553254eb7fd47930b97c2af8ffe498fa86d36641558` | parked (inert), waiting for an approver |
| `gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1` | 1,435,526 | `f354739e4688f85eafc28ef4e9ee1406a075176ada9875776cb939c790fd5961` | parked (inert), waiting for an approver |

The same hashes in base64, as gnokey prints them:
`rYR73r+oGOr+zcVTJU63/UeTC5fCr4/+SY+obTZkFVg=` (tavern) and
`81RznkaI+F6vwo706e4UBqB1F2ramHV3bLk5x5D9WWE=` (sealed).

Each submission cost 0.1 GNOT in gas. The storage deposit (capped at 10 GNOT
each by `-max-deposit`) is taken when the package is enabled, so **keep at
least 15 GNOT on the deployer until both are live.**

When deployed, 162 packages were parked on Onyx (`vm/qinertpaths`).

### Check status

```sh
gnokey query vm/qpkgmeta_json --data "gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1" \
  -remote https://rpc.onyx.testnets.gno.land:443
# "status":"inert" ... "pending":true   -> still parked
# Once live, the page renders:
#   https://onyx.testnets.gno.land/r/g15xk7p2u3q6epjq5kfyew2lku5epakfnat7fj40/sealed/v1
```

**Do not redeploy to these paths while they are parked.** An approval is tied
to the exact source bytes submitted. Fixes ship as `v2`.
