#!/usr/bin/env sh
# entrypoint.sh — runs as the host uid (via docker --user). Seeds opencode auth
# into the writable data dir, then launches opencode in the working dir.
set -eu

# Give the mapped uid a real identity (HOME + /etc/passwd entry) so Ghidra (JVM
# user.home) and angr (python getpass) work. Sets and exports HOME.
. /opt/vibe-reverse/bin/ensure-user.sh

: "${XDG_DATA_HOME:=$HOME}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
mkdir -p "$XDG_DATA_HOME/opencode" "$XDG_CACHE_HOME/opencode"

# auth.json is mounted read-only at /cfg/auth.json; opencode needs it in its data dir.
if [ -f /cfg/auth.json ]; then
  cp /cfg/auth.json "$XDG_DATA_HOME/opencode/auth.json"
  chmod 600 "$XDG_DATA_HOME/opencode/auth.json" 2>/dev/null || true
fi

exec opencode "$@"
