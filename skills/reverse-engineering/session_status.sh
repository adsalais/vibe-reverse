#!/usr/bin/env sh
# session_status.sh — read-only resume briefing for a vibe-reverse session.
# Usage: session_status.sh [session-dir]   (default: newest vibe-reverse-*/ in CWD)
set -eu
SESS="${1:-}"
if [ -z "$SESS" ]; then
  SESS=$(ls -1d vibe-reverse-*/ 2>/dev/null | sort | tail -1 | sed 's:/$::' || true)
fi
[ -n "${SESS:-}" ] && [ -d "$SESS" ] || { echo "no session found (looked for vibe-reverse-*/ in CWD)" >&2; exit 1; }

field() { grep -i "^$2:" "$1" 2>/dev/null | head -1 | cut -d: -f2- | sed 's/^ *//'; }

echo "== session: $SESS =="
echo
for d in "$SESS"/*/; do
  [ -d "$d" ] || continue
  [ -f "$d/STATE.md" ] || continue
  name=$(basename "$d")
  latest=$(ls -1 "$d"/[0-9]*-plan.md 2>/dev/null | sort | tail -1)
  [ -n "$latest" ] && latest=$(basename "$latest") || latest="(none)"
  running=$(grep -c '| running ' "$d/STATE.md" 2>/dev/null || echo 0)
  echo "- $name"
  echo "    phase:       $(field "$d/STATE.md" phase)"
  echo "    status:      $(field "$d/STATE.md" status)"
  echo "    latest plan: $latest"
  echo "    next:        $(field "$d/STATE.md" next-step)"
  echo "    running background jobs: $running"
done
