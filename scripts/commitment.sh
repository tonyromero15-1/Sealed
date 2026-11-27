#!/usr/bin/env bash
# Builds a SEALED commitment on your own machine, so your bid never leaves it
# until you reveal.
#
#   scripts/commitment.sh <your-g1-address> <price-ugnot> <amount> [salt]
#
# Prints the salt (KEEP IT: you need it to reveal) and the commitment hash
# to pass to Commit. With no salt given, a random 32-hex-char salt is made.
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "usage: $0 <g1-address> <price-ugnot> <amount> [salt]" >&2
  exit 1
fi
ADDR="$1" PRICE="$2" AMOUNT="$3"
SALT="${4:-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')}"

if [ "${#SALT}" -lt 8 ] || [ "${#SALT}" -gt 128 ]; then
  echo "salt must be 8 to 128 characters" >&2
  exit 1
fi

HASH=$(printf '%s' "$ADDR|$PRICE|$AMOUNT|$SALT" | sha256sum | cut -d' ' -f1)
echo "salt=$SALT"
echo "commitment=$HASH"
