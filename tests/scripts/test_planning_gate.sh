#!/usr/bin/env sh
# test_planning_gate.sh — SP4: re-planning describes the hypothesis loop, the
# confident/reversible vs irreversible/uncertain gate, and the objective mandatory-gate
# triggers. Static grep checks only.
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
SK=skills/re-planning/SKILL.md
[ -f "$SK" ] || fail "missing $SK"
grep -qi 'hypothes'   "$SK" || fail "no hypothesis loop"
grep -qi 'confident'  "$SK" || fail "no confident-proceed rule"
grep -qi 'reversible' "$SK" || fail "no reversible rule"
grep -qi 'mandatory'  "$SK" || fail "no mandatory-gate concept"
for t in 'running' 'new binary' 'patch' 'host'; do
  grep -qi "$t" "$SK" || fail "mandatory trigger missing: $t"
done
grep -q '🐢' "$SK" || fail "no 🐢 cost/long gate"
grep -qi 'hypothesis source' "$SK" || fail "routing-as-hypothesis-source principle missing"
echo "PASS: test_planning_gate.sh"
