#!/usr/bin/env sh
set -eu
sh tests/fixtures/build.sh >/dev/null 2>&1 || true
BIN="tests/fixtures/crackme1"
[ -f "$BIN" ] || { echo "SKIP: no compiler"; exit 0; }
fail() { echo "FAIL: $1" >&2; exit 1; }

# Templates must be valid Python (syntax) even if z3/angr aren't installed.
python3 -m py_compile skills/re-solve/templates/z3_skel.py skills/re-solve/templates/angr_skel.py \
  || fail "template syntax error"

# Solve = recover key (each username byte + 1); the REAL binary must accept it.
USER="AB"
KEY=$(python3 -c 'import sys; print("".join(chr((ord(c)+1)%256) for c in sys.argv[1]))' "$USER")
OUT=$("$BIN" "$USER" "$KEY") || fail "binary rejected recovered key (got: $OUT)"
printf '%s' "$OUT" | grep -q "Correct" || fail "expected Correct!, got: $OUT"

# If z3 is installed, the z3 skeleton must recover the same key.
if python3 -c 'import z3' >/dev/null 2>&1; then
  Z=$(python3 -c 'import sys; sys.path.insert(0,"skills/re-solve/templates"); import z3_skel; print(z3_skel.solve("AB"))')
  [ "$Z" = "$KEY" ] || fail "z3_skel disagrees: $Z != $KEY"
  echo "(z3 present: z3_skel recovered $Z)"
else
  echo "(z3 absent: templates syntax-checked only)"
fi

echo "PASS: test_solve.sh"
