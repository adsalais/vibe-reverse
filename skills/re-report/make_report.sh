#!/usr/bin/env sh
# make_report.sh — scaffold REPORT.md from the template and auto-index the
# investigation's plans, artifacts, and scripts. Fill in the prose afterward.
# Usage: make_report.sh <investigation-dir>
set -eu
DIR="${1:?usage: make_report.sh <investigation-dir>}"
[ -d "$DIR" ] || { echo "no such dir: $DIR" >&2; exit 1; }
TPL="$(dirname "$0")/report-template.md"
REPORT="$DIR/REPORT.md"

cp "$TPL" "$REPORT"

{
  echo
  echo "## Index (auto-generated)"
  echo
  echo "### Plans"
  found=0; for f in "$DIR"/[0-9]*-plan.md; do [ -e "$f" ] || continue; echo "- $(basename "$f")"; found=1; done; [ "$found" = 0 ] && echo "- (none)"
  echo
  echo "### Artifacts"
  found=0; for f in "$DIR"/artifacts/*; do [ -e "$f" ] || continue; echo "- artifacts/$(basename "$f")"; found=1; done; [ "$found" = 0 ] && echo "- (none)"
  echo
  echo "### Scripts"
  found=0; for f in "$DIR"/scripts/*; do [ -e "$f" ] || continue; echo "- scripts/$(basename "$f")"; found=1; done; [ "$found" = 0 ] && echo "- (none)"
} >> "$REPORT"

echo "wrote: $REPORT"
