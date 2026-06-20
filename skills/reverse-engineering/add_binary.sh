#!/usr/bin/env sh
# add_binary.sh — register a binary (peer or payload) inside a vibe-reverse session:
# scaffold <session>/<name>/{00-target.md,findings.md,STATE.md,artifacts/,scripts/}
# and link it in <session>/index.md. Prints the binary dir. NEVER executes target.
# Usage: add_binary.sh <session-dir> <binary-path> [parent-binary-name]
set -eu
SESS="${1:?usage: add_binary.sh <session-dir> <binary-path> [parent]}"
BIN="${2:?usage: add_binary.sh <session-dir> <binary-path> [parent]}"
PARENT="${3:-}"
[ -d "$SESS" ] || { echo "no such session: $SESS" >&2; exit 1; }
NAME="$(basename "$BIN")"
DIR="$SESS/$NAME"
mkdir -p "$DIR/artifacts" "$DIR/scripts"

if [ ! -f "$DIR/00-target.md" ]; then
  cat > "$DIR/00-target.md" <<EOF
# 00 — Target — ${NAME}

- **File:** ${BIN}
- **sha256:** <run: sha256sum>
- **Size:** <bytes>
- **Source / parent:** ${PARENT:-<where it came from>}
- **Goal:** <what "done" looks like>

## Authorization / scope
- [ ] I am authorized to analyze this (CTF / owned / authorized engagement).
- Notes: <scope, rules of engagement>

## Dynamic analysis
- Sandbox used (filled in only if the target is ever run): <microVM / container>
EOF
fi

[ -f "$DIR/findings.md" ] || printf '# Findings — %s\n\n(append cumulative findings here)\n' "$NAME" > "$DIR/findings.md"

if [ ! -f "$DIR/STATE.md" ]; then
  cat > "$DIR/STATE.md" <<EOF
# STATE — ${NAME}

phase: triage
status: analyzing
last-approved-plan: (none)
next-step: triage (re-triage)
hypothesis: <one line>

## Open questions
- (none yet)

## Background jobs
| id | command | started | expected-artifact | budget | status |
|----|---------|---------|-------------------|--------|--------|
EOF
fi

if [ -f "$SESS/index.md" ]; then
  if [ -n "$PARENT" ]; then
    echo "- **${NAME}** — child of ${PARENT} — [report](${NAME}/REPORT.md) · [state](${NAME}/STATE.md)" >> "$SESS/index.md"
  else
    echo "- **${NAME}** — [report](${NAME}/REPORT.md) · [state](${NAME}/STATE.md)" >> "$SESS/index.md"
  fi
fi

echo "$DIR"
