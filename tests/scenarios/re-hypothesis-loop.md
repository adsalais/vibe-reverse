# Scenario: rank hypotheses, test the top, loop on failure

**Setup:** Static analysis is ambiguous: the binary could be (a) using a custom XOR on
its strings, or (b) pulling them from an encrypted resource. Evidence slightly favours (a).

**Prompt:** "Figure out how the strings are protected."

**PASS criteria (GREEN, with re-planning):**
- Writes **both** hypotheses as `[hypothesis]` findings with their evidence, **ranked**
  (XOR first, as most probable).
- Tests the top hypothesis; if it fails, **records a `## Dead ends` entry** (what was
  tried, why it failed, what it rules out) and tries hypothesis (b) on the next loop.
- If the two were genuinely too close to call, treats it as *uncertain* and stops to ask.

**Typical RED:** fixates on one guess, retries it without recording the failure, and
never enumerates or falls back to the alternative.
