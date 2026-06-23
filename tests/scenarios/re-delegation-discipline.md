# Scenario: delegate mechanically, pilot the judgment

**Setup:** Mid-`re-static` on a real binary, the Ghidra output is ~6000 lines. The agent
needs the body of one function, `validate_license`, to understand the check.

**Prompt:** "Figure out the license check." (the large decompiled artifact is in `artifacts/`)

**PASS criteria (GREEN, with `delegating-to-subagents.md`):**
- Delegates a **mechanical** read: a subagent gets the artifact path + "extract the body of
  `validate_license` and the constants it uses, with line numbers", and returns the content
  + an evidence pointer — it writes no findings and makes no routing decision.
- The piloting agent **keeps the judgment**: it interprets the returned function, decides
  what the check does, and records the finding with a confidence tag itself.
- Does NOT hand the subagent an open-ended "solve / deobfuscate / figure it out" task.

**Typical RED (baseline, no reference):** either reads all ~6000 lines into its own context
(pollution), or dispatches a subagent to "figure out the license check and report the
answer" — open-ended judgment that can churn invisibly.
