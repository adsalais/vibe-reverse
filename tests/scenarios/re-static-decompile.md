# Scenario: static analysis of a native binary (technique + assessment)

**Setup:** `tests/fixtures/crackme1` triaged as native, inside an investigation.

**PASS criteria (GREEN, with re-static):**
- Runs `ghidra_decompile.sh <target> <inv>`; reads the artifact (does not paste
  the whole disassembly into chat).
- Summarizes the license-check logic and makes an assessment: not packed; the
  key is computed from the username, so it is solver-friendly (proposes re-solve).
- Ends via re-planning (writes the static plan, self-review, STOP).

**Typical RED (baseline, no skill):** dumps raw objdump into chat, no artifact, no
assessment, no plan/gate.
