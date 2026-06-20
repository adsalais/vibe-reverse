#!/usr/bin/env sh
# ghidra_decompile.sh — static disassembly/decompilation with a fallback chain.
# Usage: ghidra_decompile.sh <target> [OUTPUT_DIR]
# Tries Ghidra headless -> radare2 -> objdump. Writes <out>/artifacts/<engine>.*,
# prints "engine: <name>" and "output: <path>". NEVER executes the target.
set -eu
TARGET="${1:?usage: ghidra_decompile.sh <target> [output-dir]}"
OUT="${2:-.}"; ART="$OUT/artifacts"; mkdir -p "$ART"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }

if command -v analyzeHeadless >/dev/null 2>&1; then
  PROJ="$(mktemp -d)"
  OUT_C="$ART/ghidra.c"
  # DecompileExport.java (co-located; found via -scriptPath) writes decompiled C to $GHIDRA_OUT_C.
  GHIDRA_OUT_C="$OUT_C" analyzeHeadless "$PROJ" tmp -import "$TARGET" \
    -scriptPath "$(dirname "$0")" -postScript DecompileExport.java >/dev/null 2>&1 || true
  rm -rf "$PROJ"
  if [ -s "$OUT_C" ]; then ENGINE=ghidra; ARTOUT="$OUT_C"
  else ENGINE=ghidra-failed; ARTOUT="$OUT_C"; fi
elif command -v r2 >/dev/null 2>&1 || command -v radare2 >/dev/null 2>&1; then
  R2="$(command -v r2 || command -v radare2)"
  ARTOUT="$ART/radare2.txt"
  "$R2" -q -e scr.color=0 -c 'aaa; s main; pdf' "$TARGET" > "$ARTOUT" 2>/dev/null \
    || "$R2" -q -e scr.color=0 -c 'aa; pd 200' "$TARGET" > "$ARTOUT" 2>/dev/null
  ENGINE=radare2
else
  ARTOUT="$ART/objdump.txt"
  objdump -d "$TARGET" > "$ARTOUT"
  ENGINE=objdump
fi

echo "engine: $ENGINE"
echo "output: $ARTOUT"
[ "$ENGINE" = objdump ] && echo "note: objdump fallback (Ghidra/r2 not found on PATH — unexpected on the air-gapped image)."
exit 0
