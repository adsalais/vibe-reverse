#!/usr/bin/env sh
# test_phase_playbooks.sh — SP3a: each core-phase playbook exists, is referenced by its
# SKILL.md, and carries the five sections; the delegation reference exists. Static checks
# only (no RE tool needed).
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }

DELEG=skills/reverse-engineering/references/delegating-to-subagents.md
[ -f "$DELEG" ] || fail "missing $DELEG"

for phase in triage static dynamic; do
  pb="skills/re-$phase/references/$phase-playbook.md"
  skill="skills/re-$phase/SKILL.md"
  [ -f "$pb" ] || fail "missing $pb"
  grep -q "$phase-playbook.md" "$skill" || fail "$skill does not reference $phase-playbook.md"
  for h in "## Method" "## Failure modes" "## Red flags" "## Have I understood enough" "## Worked example"; do
    grep -q "$h" "$pb" || fail "$pb missing section: $h"
  done
done

if grep -riE 'claude|anthropic' "$DELEG" skills/re-triage/references/triage-playbook.md \
     skills/re-static/references/static-playbook.md \
     skills/re-dynamic/references/dynamic-playbook.md >/dev/null 2>&1; then
  fail "forbidden mention (claude/anthropic) in an SP3a reference"
fi

echo "PASS: test_phase_playbooks.sh"
