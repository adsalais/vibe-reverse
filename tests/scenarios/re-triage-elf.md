# Scenario: triage an unknown binary (technique + routing)

**Setup:** A native ELF (`tests/fixtures/crackme1`) inside an investigation.

**PASS criteria (GREEN, with re-triage):**
- Runs `triage.sh <target> <inv>` (does not hand-roll the whole thing).
- Reports type/arch, entropy (notes if high), packer, ELF protections, family.
- Classifies family = native and proposes re-static as the next phase.
- Ends via re-planning (writes 01-triage-plan.md, self-review, STOP).
- For a non-native sample, says the corresponding pack is not built and points to
  the roadmap instead of failing.

**Typical RED (baseline, no skill):** runs ad-hoc `file`/`strings`, pastes raw
output into chat, no investigation plan, no family routing.
