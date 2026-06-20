#!/usr/bin/env sh
# triage.sh — first-look triage of a target. NEVER executes the target.
# Usage: triage.sh <target> [OUTPUT_DIR]   (writes <out>/artifacts/triage.txt; prints summary)
set -eu
TARGET="${1:?usage: triage.sh <target> [output-dir]}"
OUT="${2:-.}"; ART="$OUT/artifacts"; mkdir -p "$ART"
REPORT="$ART/triage.txt"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }

SIZE=$(wc -c < "$TARGET" | tr -d ' ')
if command -v sha256sum >/dev/null 2>&1; then SHA=$(sha256sum "$TARGET" | cut -d' ' -f1)
elif command -v shasum >/dev/null 2>&1; then SHA=$(shasum -a 256 "$TARGET" | cut -d' ' -f1)
else SHA="(no sha tool)"; fi
FILETYPE=$(file -b "$TARGET")

# Shannon entropy (0..8 bits/byte); >7.0 hints packing/encryption.
ENTROPY=$(python3 - "$TARGET" <<'PY'
import sys, math, collections
d = open(sys.argv[1], 'rb').read()
if not d:
    print("0.00"); sys.exit()
n = len(d); c = collections.Counter(d)
print(f"{-sum((v/n)*math.log2(v/n) for v in c.values()):.2f}")
PY
)

PACKER="none detected"
if command -v upx >/dev/null 2>&1 && upx -t "$TARGET" >/dev/null 2>&1; then PACKER="UPX"
elif strings -n 4 "$TARGET" 2>/dev/null | grep -q 'UPX!'; then PACKER="UPX (signature)"; fi

PROT=""
if printf '%s' "$FILETYPE" | grep -q ELF && command -v readelf >/dev/null 2>&1; then
  HDR=$(readelf -hld "$TARGET" 2>/dev/null || true)
  printf '%s' "$HDR" | grep -q 'Type:[^Z]*DYN'  && PIE=PIE     || PIE=no-PIE
  printf '%s' "$HDR" | grep -q 'GNU_STACK.*RWE' && NX=NX-off   || NX=NX-on
  printf '%s' "$HDR" | grep -q 'GNU_RELRO'      && RELRO=RELRO || RELRO=no-RELRO
  readelf -s "$TARGET" 2>/dev/null | grep -q '__stack_chk_fail' && CAN=canary || CAN=no-canary
  PROT="$PIE, $NX, $RELRO, $CAN"
fi

# Family hint (for routing). Native = ELF/PE/Mach-O.
FAMILY=other
case "$FILETYPE" in
  *ELF*|*PE32*|*"Mach-O"*) FAMILY=native ;;
  *Java*|*"class data"*)   FAMILY=managed-java ;;
  *WebAssembly*)           FAMILY=wasm ;;
esac

{
  echo "== triage =="
  echo "file:     $TARGET"
  echo "type:     $FILETYPE"
  echo "size:     $SIZE bytes"
  echo "sha256:   $SHA"
  echo "entropy:  $ENTROPY / 8.0 (high >7.0 suggests packing/encryption)"
  echo "packer:   $PACKER"
  [ -n "$PROT" ] && echo "elf prot: $PROT"
  echo "family:   $FAMILY"
  echo
  echo "== top strings (len>=6) =="
  strings -n 6 "$TARGET" 2>/dev/null | sort | uniq -c | sort -rn | head -20
} | tee "$REPORT"
