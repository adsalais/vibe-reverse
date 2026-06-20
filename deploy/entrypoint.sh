#!/usr/bin/env sh
# entrypoint.sh — runs as the host uid (via docker --user). Seeds opencode auth
# into the writable data dir, then launches opencode in the working dir.
set -eu
: "${XDG_DATA_HOME:=$HOME}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
mkdir -p "$XDG_DATA_HOME/opencode" "$XDG_CACHE_HOME/opencode"

# Seed the pre-baked opencode provider package + cache (from the build) if the
# writable dirs are empty (first run in this throwaway tmpfs).
[ -d "${OPENCODE_DATA_BAKED:-}" ]  && cp -an "$OPENCODE_DATA_BAKED/."  "$XDG_DATA_HOME/opencode/"  2>/dev/null || true
[ -d "${OPENCODE_CACHE_BAKED:-}" ] && cp -an "$OPENCODE_CACHE_BAKED/." "$XDG_CACHE_HOME/opencode/" 2>/dev/null || true

# auth.json is mounted read-only at /cfg/auth.json; opencode needs it in its data dir.
if [ -f /cfg/auth.json ]; then
  cp /cfg/auth.json "$XDG_DATA_HOME/opencode/auth.json"
  chmod 600 "$XDG_DATA_HOME/opencode/auth.json" 2>/dev/null || true
fi

exec opencode "$@"
