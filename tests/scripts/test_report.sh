#!/usr/bin/env sh
set -eu
SCRIPT="skills/re-report/make_report.sh"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
DIR="$ROOT/inv"; mkdir -p "$DIR/artifacts" "$DIR/scripts"
printf '# 01 triage plan\n' > "$DIR/01-triage-plan.md"
printf 'objdump output\n'   > "$DIR/artifacts/objdump.txt"
printf 'print("k")\n'       > "$DIR/scripts/solve.py"
fail() { echo "FAIL: $1" >&2; exit 1; }

OUT=$(sh "$SCRIPT" "$DIR") || fail "make_report.sh nonzero"
R="$DIR/REPORT.md"
[ -f "$R" ] || fail "REPORT.md not created"
for s in "Outcome" "Approaches tried" "Dead ends" "Reproduction" "Index"; do
  grep -q "$s" "$R" || fail "missing section: $s"
done
grep -q "01-triage-plan.md" "$R"     || fail "plan not indexed"
grep -q "artifacts/objdump.txt" "$R" || fail "artifact not indexed"
grep -q "scripts/solve.py" "$R"      || fail "script not indexed"

echo "PASS: test_report.sh"
