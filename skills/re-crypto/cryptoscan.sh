#!/usr/bin/env sh
# cryptoscan.sh — scan a target for crypto constants/algorithms. NEVER executes it.
# Uses yara crypto rules if present + built-in constant fingerprints. Tool-optional.
# Usage: cryptoscan.sh <target> <out-dir>
set -eu
TARGET="${1:?usage: cryptoscan.sh <target> <out-dir>}"
OUT="${2:?usage: cryptoscan.sh <target> <out-dir>}"
ART="$OUT/artifacts/crypto"; mkdir -p "$ART"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }
REPORT="$ART/cryptoscan.txt"

{
  echo "== cryptoscan: $TARGET =="
  if command -v capa >/dev/null 2>&1; then
    echo "-- capa crypto capabilities --"
    capa "$TARGET" 2>/dev/null | grep -iE 'crypt|aes|rc4|chacha|base64|hash|xor' \
      || echo "(none flagged by capa)"
  fi
  echo "-- constant fingerprints --"
  if command -v xxd >/dev/null 2>&1; then
    HEX=$(xxd -p "$TARGET" 2>/dev/null | tr -d '\n')
    printf '%s' "$HEX" | grep -qi '637c777bf26b6fc5' \
      && echo "AES S-box (63 7c 77 7b f2 6b 6f c5 ...) FOUND" || echo "AES S-box: not found"
  fi
  echo "-- base64 alphabets in strings --"
  strings -n 32 "$TARGET" 2>/dev/null \
    | grep -E 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' | head -3 \
    || echo "(standard alphabet not seen; a custom alphabet may exist)"
} | tee "$REPORT"
