#!/usr/bin/env sh
# new_investigation.sh — scaffold a dated investigation folder under docs/reverse/.
# Usage: new_investigation.sh <slug> [YYYY-MM-DD]   (date defaults to today)
# Prints the created directory path (relative).
set -eu
SLUG="${1:?usage: new_investigation.sh <slug> [YYYY-MM-DD]}"
DATE="${2:-$(date +%Y-%m-%d)}"
DIR="docs/reverse/${DATE}-${SLUG}"
mkdir -p "$DIR/artifacts" "$DIR/scripts"

if [ ! -f "$DIR/00-target.md" ]; then
  cat > "$DIR/00-target.md" <<EOF
# 00 — Target — ${SLUG}

- **File:** <path>
- **sha256:** <run: sha256sum / shasum -a 256>
- **Size:** <bytes>
- **Source:** <where it came from>
- **Goal:** <what "done" looks like>

## Authorization / scope
- [ ] I am authorized to analyze this (CTF / owned / authorized engagement).
- Notes: <scope, rules of engagement>

## Dynamic analysis
- Sandbox used (filled in only if the target is ever run): <container / VM>
EOF
fi

[ -f "$DIR/findings.md" ] || printf '# Findings — %s\n\n(append cumulative findings here)\n' "$SLUG" > "$DIR/findings.md"

echo "$DIR"
