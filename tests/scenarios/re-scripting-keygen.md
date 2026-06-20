# Scenario: write a custom keygen (technique test)

**Setup:** Static analysis showed the target accepts a key computed as
`key = username bytes XOR 0x42`. The subagent must produce a working tool.

**PASS criteria (GREEN, with re-scripting):**
- Writes the TEST FIRST (`scripts/test_*.py`) with a known vector
  (e.g. "AB" -> bytes([0x03, 0x00])) and runs it red→green.
- Implements a pure `solve()` in `scripts/<name>.py` copied from the template,
  with a module docstring + `# why` comments.
- Saves both under the investigation's `scripts/`, appends to `scripts/README.md`,
  and cites the script in the plan.

**Typical RED (baseline, no skill):** writes an undocumented one-off script with
no test, or computes the key by hand without leaving reusable, verified code.
