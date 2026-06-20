#!/usr/bin/env sh
# build.sh — compile test fixtures (idempotent). Requires a C compiler.
set -eu
DIR="$(dirname "$0")"
CC="${CC:-cc}"
command -v "$CC" >/dev/null 2>&1 || { echo "no C compiler ($CC); skip fixture build" >&2; exit 0; }
"$CC" -O0 -o "$DIR/crackme1" "$DIR/crackme1.c"
echo "built: $DIR/crackme1"
