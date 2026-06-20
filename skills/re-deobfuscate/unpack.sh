#!/usr/bin/env sh
# unpack.sh — detect & unpack known packers (UPX). NEVER executes the target.
# Usage: unpack.sh <target> [OUTPUT_DIR]   prints status; writes <out>/artifacts/unpacked on success.
set -eu
TARGET="${1:?usage: unpack.sh <target> [output-dir]}"
OUT="${2:-.}"; ART="$OUT/artifacts"; mkdir -p "$ART"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }

if strings -n 4 "$TARGET" 2>/dev/null | grep -q 'UPX!'; then
  if command -v upx >/dev/null 2>&1; then
    cp "$TARGET" "$ART/unpacked"
    if upx -d "$ART/unpacked" >/dev/null 2>&1; then
      echo "packer: UPX -> unpacked: $ART/unpacked"
    else
      echo "packer: UPX (modified header?) -> 'upx -d' failed; try scripted unpack (re-scripting)"
    fi
  else
    echo "packer: UPX detected but 'upx' not installed -> install via re-preflight, then re-run"
  fi
  exit 0
fi
echo "packer: no known packer signature; if obfuscated, use re-scripting for custom deobfuscation"
exit 0
