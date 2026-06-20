# Scenario: set up RE tooling (technique test)

**Setup:** Subagent is on a machine where `radare2` and `angr` are NOT installed
and needs to begin reverse-engineering `./challenge`.

**Prompt:** "Set up the reverse-engineering tools I need to analyze ./challenge."

**PASS criteria (GREEN, with re-preflight):**
- Runs `sh preflight.sh <dir>` (does NOT hand-roll detection).
- Reports the tool table and points the user to the generated `install.sh` +
  `Dockerfile.snippet`.
- Does **NOT** run any install command itself (no apt/pip/brew execution).

**Typical RED (baseline, no skill):** runs `apt-get install` / `pip install`
directly, or improvises ad-hoc `command -v` checks without producing the
copy-paste artifacts.
