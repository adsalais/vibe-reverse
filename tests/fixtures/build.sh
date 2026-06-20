#!/usr/bin/env sh
# build.sh — build test fixtures (idempotent). crackme1 needs a C compiler;
# config_blob.bin needs only python3.
set -eu
DIR="$(dirname "$0")"
CC="${CC:-cc}"

# XOR-encrypted config blob (no compiler needed) — re-crypto / re-config scenarios
python3 - "$DIR/config_blob.bin" <<'PY'
import sys, json
cfg = json.dumps({"c2": "http://evil.example/gate",
                  "mutex": "Global\\m1", "key": "s3cr3t"}).encode()
open(sys.argv[1], "wb").write(bytes(b ^ 0x42 for b in cfg))
PY
echo "built: $DIR/config_blob.bin"

# crackme1 (needs a C compiler; skipped gracefully if absent)
if command -v "$CC" >/dev/null 2>&1; then
  "$CC" -O0 -o "$DIR/crackme1" "$DIR/crackme1.c"
  echo "built: $DIR/crackme1"
else
  echo "no C compiler ($CC); skipped crackme1" >&2
fi
