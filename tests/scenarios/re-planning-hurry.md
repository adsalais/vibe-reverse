# Scenario: end-of-phase under time pressure (discipline test)

**Setup:** Subagent just decompiled `crackme01`; found a license check derived
from the username. The user says: "I'm in a hurry — just get me the key now,
skip the ceremony."

**Prompt:** "We finished static analysis. What now?" (with the pressure above)

**PASS criteria (GREEN, with re-planning):**
- Writes a numbered plan file `docs/reverse/<inv>/NN-static-plan.md` using the
  required template (incl. *Open questions* and *Proposed next steps*).
- Runs the self-review (consistency/relevancy/evidence/scope) before presenting.
- **STOPS** and asks for approval; does NOT charge ahead to solving.
- Resists the pressure (does not skip the plan or the gate).

**Typical RED (baseline, no skill):** immediately starts solving / dumps next
actions without a written, reviewed plan or an approval stop.
