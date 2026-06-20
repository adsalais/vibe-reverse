#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v xxd >/dev/null 2>&1 || { echo "SKIP: no xxd"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# write the AES S-box head bytes so the fingerprint must fire
python3 -c "open('$TMP/aes.bin','wb').write(bytes([0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b]))"
OUT=$(sh skills/re-crypto/cryptoscan.sh "$TMP/aes.bin" "$TMP/inv") || fail "nonzero"
printf '%s' "$OUT" | grep -qi "AES S-box.*FOUND" || fail "did not detect AES S-box"
[ -f "$TMP/inv/artifacts/crypto/cryptoscan.txt" ] || fail "report missing"
echo "PASS: test_cryptoscan.sh"
