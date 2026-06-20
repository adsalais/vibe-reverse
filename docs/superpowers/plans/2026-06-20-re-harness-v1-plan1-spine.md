# RE Harness v1 — Plan 1: Spine & Packaging — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the installable, testable harness *skeleton* — orchestrator + preflight + planning/self-review/gate + on-the-fly scripting — so a user can install it in Claude Code or opencode, run preflight, and start a human-piloted investigation, before any deep RE phase exists.

**Architecture:** A flat `skills/` family of `SKILL.md` skills plus portable POSIX-sh / Python-3 helper scripts. Skills are authored with the `superpowers:writing-skills` RED→GREEN→REFACTOR cycle (subagent pressure/application scenarios); scripts use real tests (POSIX-sh assertions + `pytest`/`py_compile`). All heavy output is written to files; a human approval gate plus a pre-gate self-review govern progression.

**Tech Stack:** Markdown (`SKILL.md`, agentskills.io format), POSIX `sh`, Python 3 (`pytest`), `git`. Install target: `~/.claude/skills/` (read by **both** Claude Code and opencode).

**Implements (spec sections):** §1–§4a (loop + spine), §4d/§6 (plan, self-review, gate), §7 (preflight artifacts), §8 (scripting), §11/§11a (packaging + dual-agent install), parts of §10 (skill testing).
**Deferred to Plans 2–4:** `re-triage`, `re-static`, `re-deobfuscate`, `re-solve`, `re-dynamic`, `re-report`; fixtures (crackme / UPX / z3); ghidra-headless & protections references; the example investigation.

**Plan sequence:** Plan 1 of 4 (Spine & packaging → Triage+Static → Deep analysis → Reporting+example).

---

## File Structure (created by this plan)

| Path | Responsibility |
|---|---|
| `.gitignore` | Ignore runtime investigations (`docs/reverse/*`) + Python caches; keep the spec/plans. |
| `README.md` | What the harness is, the loop, link to spec, 30-second quickstart. |
| `INSTALL.md` | Copy-paste install for Claude Code **and** opencode. |
| `references/agent-tools.md` | CC↔opencode tool-name map + portability rules (relative paths, naming, etc.). |
| `skills/reverse-engineering/SKILL.md` | Tiny orchestrator: records authorization, scaffolds the investigation, routes to phases. |
| `skills/reverse-engineering/new_investigation.sh` | Scaffolds `docs/reverse/<date>-<slug>/` (00-target, findings, artifacts/, scripts/). |
| `skills/re-preflight/SKILL.md` | "Detect, never install" workflow. |
| `skills/re-preflight/preflight.sh` | Probe tools; emit `install.sh` + `Dockerfile.snippet`. |
| `skills/re-preflight/references/tool-cheatsheet.md` | Tool → purpose map. |
| `skills/re-planning/SKILL.md` | Plan artifact + self-review + STOP gate (discipline). |
| `skills/re-planning/reviewer-prompt.md` | Prompt for the independent plan-reviewer subagent. |
| `skills/re-scripting/SKILL.md` | On-the-fly Python with TDD + learner docs. |
| `skills/re-scripting/script_template.py` | Documented script skeleton to copy. |
| `tests/README.md` | How to run skill scenarios (subagent) + script tests. |
| `tests/scenarios/*.md` | RED/GREEN scenarios per skill (committed test cases). |
| `tests/scripts/test_preflight.sh` | Behavioral test for `preflight.sh`. |
| `tests/scripts/test_new_investigation.sh` | Behavioral test for `new_investigation.sh`. |
| `tests/scripts/test_script_template.py` | Smoke test for `script_template.py`. |

---

## Task 1: Repo scaffolding (gitignore, README, INSTALL, agent-tools)

**Files:**
- Create: `.gitignore`, `README.md`, `INSTALL.md`, `references/agent-tools.md`

- [ ] **Step 1: Write `.gitignore`**

```gitignore
# Runtime investigations may hold sensitive target data — never commit them,
# except a curated example added later (Plan 4).
docs/reverse/*
!docs/reverse/_example/

# Python
__pycache__/
*.pyc
.pytest_cache/

# OS noise
.DS_Store
```

- [ ] **Step 2: Write `README.md`**

```markdown
# Reverse-Engineering Harness

A portable family of [skills](https://agentskills.io) that lets you *pilot* a
reverse-engineering investigation through a disciplined loop:

> analyze → write a plan → **you approve** → execute the next phase → repeat → report

Works in **Claude Code** and **opencode** (same install). Heavy tool output goes
to files; you review a short, self-checked plan at each step.

- **Design spec:** `docs/superpowers/specs/2026-06-20-reverse-engineering-harness-design.md`
- **Install:** see `INSTALL.md`
- **Status:** v1 = spine + native/CTF binary vertical (built incrementally).

## Quickstart
1. Install the skills (`INSTALL.md`).
2. In your agent: *"Reverse-engineer ./challenge"* — the `reverse-engineering`
   skill takes over: checks tooling, creates `docs/reverse/<date>-<slug>/`, and
   walks you through triage with reviewed plans.

## Safety
Targets are analyzed statically by default and only **run inside a sandbox**
(never the host). Only analyze artifacts you are authorized to (CTF / owned /
authorized engagement); the harness records the authorization.
```

- [ ] **Step 3: Write `INSTALL.md`** (verbatim from spec §11a)

```markdown
# Installing the RE harness

opencode (≥ v1.0.190) reads the **same `~/.claude/skills/` tree** as Claude Code,
so one install serves both. No manifest, no config — skills auto-load by their
`description`.

## Global (both agents)
From the cloned repo root, symlink (recommended for dev) each skill:
```sh
for d in skills/*/; do
  ln -s "$PWD/$d" "$HOME/.claude/skills/$(basename "$d")"
done
```
Or copy them instead: `cp -r skills/* ~/.claude/skills/`

## Per-project (committed to a repo)
Place skills under the repo's `.claude/skills/` (both agents read it) or the
tool-neutral `.agents/skills/`.

## opencode-native (optional)
`~/.config/opencode/skills/<name>/` (global) or `.opencode/skills/<name>/`
(project); or point opencode at any folder via `opencode.json`:
```json
{ "skills": { "paths": ["/abs/path/to/skills"] } }
```

## Verify
Ask your agent: *"list your reverse-engineering skills"* — you should see
`reverse-engineering`, `re-preflight`, `re-planning`, `re-scripting`.

> Note: opencode's bundled helper-file support (scripts/ inside a skill) is
> confirmed in source but undocumented — pin a known opencode version if relied on.
```

- [ ] **Step 4: Write `references/agent-tools.md`**

```markdown
# Agent tool map & portability rules

These skills are agent-agnostic. Keep them portable:

| Concept | Claude Code | opencode |
|---|---|---|
| Run a skill | auto by `description`, or `/skill-name` | auto by `description` (no slash for skills) |
| Subagent | `Agent` tool | agent/subagent invocation |
| Shell | `Bash` | `bash` |
| Read/Write files | `Read`/`Write`/`Edit` | `read`/`write`/`edit` |

**Rules for every skill in this repo**
- Reference helper files by **relative path** (`preflight.sh`, `scripts/x.py`),
  never `${CLAUDE_SKILL_DIR}` (Claude-Code-only; inert elsewhere).
- The `description` is the portable discovery contract: third person, "Use
  when…", trigger keywords. ≤ 1024 chars.
- `name` = lowercase-alphanumeric-hyphen, ≤ 64 chars, **equal to the directory
  name**, no `anthropic`/`claude`/XML.
- Don't rely on `allowed-tools` to auto-grant bash; assume the agent must already
  permit it.
- Keep each `SKILL.md` < 500 lines; push detail into `references/`.
- Scripts: POSIX `sh` / `python3`, std-lib-first, non-interactive, `--help`-able.
```

- [ ] **Step 5: Commit**

```sh
git add .gitignore README.md INSTALL.md references/agent-tools.md
git commit -m "Plan1 T1: repo scaffolding (gitignore, README, INSTALL, agent-tools)"
```

---

## Task 2: Skill test harness (how we RED/GREEN test skills)

**Files:**
- Create: `tests/README.md`, `tests/scenarios/.gitkeep`

- [ ] **Step 1: Write `tests/README.md`**

````markdown
# Testing the harness

## Script tests (deterministic, run locally)
```sh
sh tests/scripts/test_preflight.sh
sh tests/scripts/test_new_investigation.sh
python3 -m pytest tests/scripts/test_script_template.py -q
```
All must exit 0.

## Skill scenario tests (RED → GREEN, via a subagent)
Each skill has scenario(s) in `tests/scenarios/<skill>-<case>.md`. To test a
skill, follow `superpowers:writing-skills`:

1. **RED (baseline):** dispatch a fresh subagent with the scenario text **and no
   access to the skill**. Record what it does (verbatim). This proves the skill is
   needed.
2. **GREEN (verify):** dispatch a fresh subagent with the scenario **and the
   skill loaded**. Confirm it now complies (see each scenario's "PASS criteria").
3. **REFACTOR:** if it finds a loophole, add an explicit counter to the skill and
   re-run GREEN.

A skill is "done" only when GREEN passes under the scenario's stated pressure.
````

- [ ] **Step 2: Keep the scenarios dir tracked**

Create an empty `tests/scenarios/.gitkeep` (scenario files are added per skill below).

- [ ] **Step 3: Commit**

```sh
git add tests/README.md tests/scenarios/.gitkeep
git commit -m "Plan1 T2: skill/script test harness conventions"
```

---

## Task 3: `re-preflight` skill + `preflight.sh` (detect, never install)

**Files:**
- Create: `tests/scripts/test_preflight.sh`, `skills/re-preflight/preflight.sh`,
  `skills/re-preflight/references/tool-cheatsheet.md`,
  `skills/re-preflight/SKILL.md`, `tests/scenarios/re-preflight-missing-tools.md`

- [ ] **Step 1: Write the failing test `tests/scripts/test_preflight.sh`**

```sh
#!/usr/bin/env sh
# Behavioral test for preflight.sh — host-independent assertions.
set -eu
SCRIPT="skills/re-preflight/preflight.sh"
OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

OUTPUT="$(sh "$SCRIPT" "$OUT")" || fail "preflight.sh exited non-zero"

# Table prints every registry tool, regardless of what's installed:
for t in file radare2 angr z3 binwalk; do
  printf '%s' "$OUTPUT" | grep -q "$t" || fail "table missing row: $t"
done
printf '%s' "$OUTPUT" | grep -qi "TOOL" || fail "table header missing"

# Artifacts created:
[ -f "$OUT/install.sh" ] || fail "install.sh not created"
[ -x "$OUT/install.sh" ] || fail "install.sh not executable"
head -n1 "$OUT/install.sh" | grep -q '^#!' || fail "install.sh missing shebang"
[ -f "$OUT/Dockerfile.snippet" ] || fail "Dockerfile.snippet not created"
grep -qi "ghidra" "$OUT/Dockerfile.snippet" || fail "Dockerfile.snippet missing Ghidra recipe"

echo "PASS: test_preflight.sh"
```

- [ ] **Step 2: Run it — verify it FAILS**

Run: `sh tests/scripts/test_preflight.sh`
Expected: FAIL (preflight.sh does not exist yet → non-zero / "No such file").

- [ ] **Step 3: Implement `skills/re-preflight/preflight.sh`**

```sh
#!/usr/bin/env sh
# preflight.sh — detect reverse-engineering tools; emit install.sh + Dockerfile.snippet.
# NEVER installs anything. POSIX sh; Linux + macOS. Usage: preflight.sh [OUTPUT_DIR]
set -eu

OUT="${1:-.}"; mkdir -p "$OUT"
INSTALL="$OUT/install.sh"; DOCKER="$OUT/Dockerfile.snippet"

case "$(uname -s 2>/dev/null || echo unknown)" in
  Linux)  APT="sudo apt-get install -y" ;;
  Darwin) APT="brew install" ;;
  *)      APT="# install via your package manager:" ;;
esac

# Registry: cmd|purpose|apt_pkg|pip_pkg   (pip_pkg set => detect as python module)
REG="$(mktemp)"; trap 'rm -f "$REG"' EXIT
cat > "$REG" <<'EOF'
file|identify file type & format|file|
strings|extract strings (binutils)|binutils|
objdump|disassembly (binutils)|binutils|
readelf|ELF inspection (binutils)|binutils|
nm|symbol listing (binutils)|binutils|
xxd|hex dump|xxd|
binwalk|firmware extraction & entropy|binwalk|
radare2|disassembly & analysis|radare2|
gdb|dynamic debugging|gdb|
ltrace|library-call tracing|ltrace|
strace|syscall tracing|strace|
upx|(un)packing UPX binaries|upx-ucl|
python3|scripting runtime|python3|
angr|symbolic execution (python)|python3-pip|angr
z3|SMT solver (python)|python3-pip|z3-solver
EOF

printf '%-10s %-6s %s\n' TOOL FOUND PURPOSE
printf '%-10s %-6s %s\n' ---------- ------ -------------------------------

MISS_APT=""; MISS_PIP=""
while IFS='|' read -r cmd purpose apt pip; do
  [ -z "${cmd:-}" ] && continue
  case "$cmd" in
    angr) python3 -c 'import angr' >/dev/null 2>&1 && found=yes || found=no ;;
    z3)   python3 -c 'import z3'   >/dev/null 2>&1 && found=yes || found=no ;;
    *)    command -v "$cmd" >/dev/null 2>&1 && found=yes || found=no ;;
  esac
  printf '%-10s %-6s %s\n' "$cmd" "$found" "$purpose"
  if [ "$found" = no ]; then
    if [ -n "$pip" ]; then MISS_PIP="$MISS_PIP $pip"
    elif [ -n "$apt" ]; then MISS_APT="$MISS_APT $apt"; fi
  fi
done < "$REG"

# de-duplicate
MISS_APT="$(printf '%s\n' $MISS_APT | sort -u | tr '\n' ' ')"
MISS_PIP="$(printf '%s\n' $MISS_PIP | sort -u | tr '\n' ' ')"

# ---- install.sh (copy-paste; user runs it themselves) ----
{
  echo '#!/usr/bin/env sh'
  echo '# Generated by re-preflight. REVIEW before running. Installs MISSING tools only.'
  echo 'set -eu'
  [ -n "$(echo "$MISS_APT" | tr -d ' ')" ] && { echo '# system packages:'; echo "$APT $MISS_APT"; }
  [ -n "$(echo "$MISS_PIP" | tr -d ' ')" ] && { echo '# python packages:'; echo "python3 -m pip install $MISS_PIP"; }
  echo '# Ghidra (manual — not an apt package): install a JDK 17+, then:'
  echo '#   download from https://github.com/NationalSecurityAgency/ghidra/releases'
  echo '#   unzip, then add ghidra_*/support to PATH (provides analyzeHeadless).'
} > "$INSTALL"
chmod +x "$INSTALL"

# ---- Dockerfile.snippet (paste into a Dockerfile) ----
{
  echo '# --- RE tools (generated by re-preflight) ---'
  [ -n "$(echo "$MISS_APT" | tr -d ' ')" ] && echo "RUN apt-get update && apt-get install -y$MISS_APT"
  [ -n "$(echo "$MISS_PIP" | tr -d ' ')" ] && echo "RUN pip install$MISS_PIP"
  echo '# Ghidra: needs a JDK + manual download; e.g.'
  echo '#   RUN apt-get install -y openjdk-17-jdk unzip wget \'
  echo '#    && wget -O /tmp/ghidra.zip <release-url> && unzip /tmp/ghidra.zip -d /opt'
  echo '#   ENV PATH="/opt/ghidra_VER/support:$PATH"'
} > "$DOCKER"

echo
echo "Wrote: $INSTALL"
echo "Wrote: $DOCKER"
echo "re-preflight never installs anything; review and run install.sh yourself."
```

- [ ] **Step 4: Run the test — verify it PASSES**

Run: `sh tests/scripts/test_preflight.sh`
Expected: `PASS: test_preflight.sh`

- [ ] **Step 5: Write `skills/re-preflight/references/tool-cheatsheet.md`**

```markdown
# RE tool cheat-sheet (which tool for what)

| Tool | Use it for |
|---|---|
| `file`, `xxd`, `strings` | first look: format, magic, embedded text |
| `readelf`, `objdump`, `nm` | ELF headers, sections, disassembly, symbols |
| `binwalk` | find/extract embedded files & filesystems; entropy (packing) |
| `radare2` / `rizin` | interactive disassembly & analysis, scripting (r2pipe) |
| Ghidra (`analyzeHeadless`) | decompilation to C; batch/scripted analysis |
| `upx` | detect/unpack UPX-packed binaries |
| `gdb`, `ltrace`, `strace` | dynamic: breakpoints, library/syscall traces (sandbox only) |
| `angr`, `z3` (python) | symbolic execution / constraint solving (keygen, paths) |
```

- [ ] **Step 6: Write the test scenario `tests/scenarios/re-preflight-missing-tools.md`**

```markdown
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
```

- [ ] **Step 7: Author `skills/re-preflight/SKILL.md`** to satisfy this contract

Frontmatter (verbatim):

```yaml
---
name: re-preflight
description: Use when setting up reverse-engineering tooling or when an RE tool (Ghidra, radare2, binwalk, angr, z3, gdb) is missing or "command not found" — detects what is installed and writes copy-paste install.sh and a Dockerfile snippet without installing anything. Keywords: install RE tools, missing tool, environment setup, ghidra not found.
---
```

Required contents (the body MUST):
1. State the core rule up front: **detect and report only — never install anything.**
2. Give the command: `sh preflight.sh <investigation-dir>` (relative path) and explain it prints a tool table and writes `install.sh` + `Dockerfile.snippet` into that dir.
3. Explain the two artifacts and that **the user runs `install.sh` themselves**.
4. Note Ghidra is manual (JDK + download; not apt).
5. Note graceful degradation: if a tool is absent, phase skills fall back and say so.
6. Link the cheat-sheet: "See `references/tool-cheatsheet.md` for tool→purpose."
7. < 200 words; relative paths only.

- [ ] **Step 8: RED/GREEN test the skill** (per `tests/README.md`)

RED: dispatch a subagent with `re-preflight-missing-tools.md` and **no skill**; record behavior.
GREEN: dispatch a subagent with the scenario **and** `re-preflight` loaded; confirm all PASS criteria. If it installs anything or skips the artifacts, add an explicit counter to the skill and re-run.

- [ ] **Step 9: Commit**

```sh
git add skills/re-preflight tests/scripts/test_preflight.sh tests/scenarios/re-preflight-missing-tools.md
git commit -m "Plan1 T3: re-preflight skill + preflight.sh (detect, never install)"
```

---

## Task 4: `re-planning` skill + reviewer prompt (plan + self-review + gate)

**Files:**
- Create: `skills/re-planning/reviewer-prompt.md`, `skills/re-planning/SKILL.md`,
  `tests/scenarios/re-planning-hurry.md`

- [ ] **Step 1: Write `skills/re-planning/reviewer-prompt.md`** (independent reviewer subagent)

```markdown
# Independent plan reviewer

You are reviewing a reverse-engineering phase plan BEFORE it reaches the human.
You are adversarial: assume something is wrong until shown otherwise.

Inputs you will be given: the draft plan, plus `00-target.md` and `findings.md`.

Check and report issues for each:
1. **Consistency** — does the *Assessment* contradict the *Proposed next steps*?
   Does anything contradict `findings.md` or the goal in `00-target.md`?
2. **Relevancy** — is every proposed step justified by a finding and does it
   advance the goal? Is the *recommended* step actually the highest-value one?
3. **Evidence/honesty** — is every claim backed by an `artifacts/` file, or
   explicitly marked as an unconfirmed hypothesis? Flag overclaims.
4. **Scope** — does it propose the NEXT step, not a five-step leap?

Return JSON: {"issues":[{"type":"consistency|relevancy|evidence|scope",
"where":"...","problem":"...","fix":"..."}], "verdict":"ok|revise"}.
Default to "revise" if uncertain.
```

- [ ] **Step 2: Write the test scenario `tests/scenarios/re-planning-hurry.md`** (discipline)

```markdown
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
```

- [ ] **Step 3: Run RED baseline**

Dispatch a subagent with `re-planning-hurry.md` and **no skill**. Record verbatim how it skips the plan/gate (these rationalizations become the skill's red-flags table).

- [ ] **Step 4: Author `skills/re-planning/SKILL.md`** to satisfy the contract

Frontmatter (verbatim):

```yaml
---
name: re-planning
description: Use when ending a reverse-engineering phase and proposing next steps, before continuing — writes a numbered investigation plan, self-reviews it for consistency and relevancy, then stops for human approval. Symptoms you are about to violate it: "I'll just continue", "skip the plan", "the user is in a hurry". Keywords: RE plan, next steps, approval gate, checkpoint.
---
```

Required contents (the body MUST contain):
1. Core principle: **the plan is the gate artifact; the human pilots.** "Violating the letter of the gate is violating the spirit of the gate."
2. The **plan template** (verbatim, matching spec §6): sections *What I did / What I found / Assessment / Open questions / Proposed next steps / Decision needed from you*.
3. Save location: `docs/reverse/<inv>/NN-<phase>-plan.md` (zero-padded `NN`).
4. **Self-review checklist** run *before presenting*: consistency, relevancy, evidence/honesty, scope — fix inline.
5. **Escalation rule:** for complex/high-uncertainty plans, dispatch the reviewer subagent using `reviewer-prompt.md` (pass the plan + `00-target.md` + `findings.md`); resolve its issues before the gate. Triggers: high-cost/irreversible next step (e.g. running the target), low confidence/many open questions, branch/backtrack, multiple competing paths.
6. **STOP discipline:** after the plan, present a ≤3-line summary + the file path and WAIT for approval.
7. **Red-flags table** (forbidden rationalizations) built from the RED baseline, e.g. "the next step is obviously fine", "I'll save a round-trip", "the user is in a hurry", "the plan is trivial" → all mean STOP and write/await the plan.
8. How the user approves (chat: "approved" / "do 1, skip 2" / "redirect"; or edit the file then "go").
9. Relative paths only.

- [ ] **Step 5: Run GREEN verification**

Dispatch a subagent with the scenario **and** `re-planning`. Confirm all PASS criteria. Add explicit counters for any new rationalization and re-run until it holds under pressure.

- [ ] **Step 6: Commit**

```sh
git add skills/re-planning tests/scenarios/re-planning-hurry.md
git commit -m "Plan1 T4: re-planning skill (plan template + self-review + STOP gate)"
```

---

## Task 5: `re-scripting` skill + `script_template.py` (tested, documented code)

**Files:**
- Create: `tests/scripts/test_script_template.py`,
  `skills/re-scripting/script_template.py`, `skills/re-scripting/SKILL.md`,
  `tests/scenarios/re-scripting-keygen.md`

- [ ] **Step 1: Write the failing test `tests/scripts/test_script_template.py`**

```python
import subprocess, sys, py_compile
from pathlib import Path

TEMPLATE = Path("skills/re-scripting/script_template.py")

def test_template_exists():
    assert TEMPLATE.is_file(), "script_template.py missing"

def test_template_compiles():
    # Raises py_compile.PyCompileError on syntax errors.
    py_compile.compile(str(TEMPLATE), doraise=True)

def test_template_has_help():
    # The skeleton must expose a --help (argparse) and exit 0.
    r = subprocess.run([sys.executable, str(TEMPLATE), "--help"],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert "usage" in r.stdout.lower()
```

- [ ] **Step 2: Run it — verify it FAILS**

Run: `python3 -m pytest tests/scripts/test_script_template.py -q`
Expected: FAIL (`script_template.py` missing).

- [ ] **Step 3: Implement `skills/re-scripting/script_template.py`**

```python
#!/usr/bin/env python3
"""<one line: what this script recovers/transforms and for which target>.

WHY: explain the reverse-engineering reasoning for a learner — what you observed
in the binary, and why this code reproduces it. Keep it honest about assumptions.

Usage:
    python3 script_template.py [--input ...]
"""
import argparse


def solve(data: bytes) -> bytes:
    """The deterministic core (parser / transform / keygen).

    Keep this pure and side-effect-free so it can be unit-tested with known
    input/output vectors (see the matching test_*.py). Replace the body.
    """
    # why: placeholder identity transform — replace with the real logic.
    return data


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--input", default="", help="input value to process")
    args = p.parse_args()
    print(solve(args.input.encode()).decode(errors="replace"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the test — verify it PASSES**

Run: `python3 -m pytest tests/scripts/test_script_template.py -q`
Expected: 3 passed.

- [ ] **Step 5: Write scenario `tests/scenarios/re-scripting-keygen.md`**

```markdown
# Scenario: write a custom keygen (technique test)

**Setup:** Static analysis showed the target accepts a key computed as
`key = username bytes XOR 0x42`. The subagent must produce a working tool.

**PASS criteria (GREEN, with re-scripting):**
- Writes the TEST FIRST (`scripts/test_*.py`) with a known vector
  (e.g. "AB" -> bytes([0x03,0x00])) and runs it red→green.
- Implements a pure `solve()` in `scripts/<name>.py` copied from the template,
  with a module docstring + `# why` comments.
- Saves both under the investigation's `scripts/`, appends to `scripts/README.md`,
  and cites the script in the plan.

**Typical RED (baseline, no skill):** writes an undocumented one-off script with
no test, or computes the key by hand without leaving reusable, verified code.
```

- [ ] **Step 6: Author `skills/re-scripting/SKILL.md`** to satisfy the contract

Frontmatter (verbatim):

```yaml
---
name: re-scripting
description: Use when a reverse-engineering task needs custom code — a format parser, deobfuscation routine, keygen, or angr/z3 harness — to produce a tested, documented Python script saved in the investigation's scripts/ folder. Keywords: RE script, custom tool, parser, keygen, angr script, z3 harness, automate analysis.
---
```

Required contents (the body MUST):
1. When to write a script vs a one-off shell command.
2. **REQUIRED SUB-SKILL: Use superpowers:test-driven-development** — test first, watch it fail, implement, green.
3. Copy `script_template.py` as the starting point; keep the deterministic logic in a pure function.
4. **Pragmatic testing stance** (spec §8): unit-test deterministic logic with known vectors; for binary-coupled code (angr glue, ptrace), verify by running + capture the sample/expected as a fixture and **document** how it was verified — don't fake unit tests.
5. Inline docs for a learner: module docstring + `# why` comments explaining the RE reasoning.
6. Save to `<inv>/scripts/`; append a one-liner to `scripts/README.md`; cite the script in the current plan.
7. Relative paths only.

- [ ] **Step 7: RED/GREEN test the skill** with `re-scripting-keygen.md` (baseline without, verify with). Close loopholes; re-run.

- [ ] **Step 8: Commit**

```sh
git add skills/re-scripting tests/scripts/test_script_template.py tests/scenarios/re-scripting-keygen.md
git commit -m "Plan1 T5: re-scripting skill + tested, documented script template"
```

---

## Task 6: `reverse-engineering` orchestrator + `new_investigation.sh`

**Files:**
- Create: `tests/scripts/test_new_investigation.sh`,
  `skills/reverse-engineering/new_investigation.sh`,
  `skills/reverse-engineering/SKILL.md`,
  `tests/scenarios/reverse-engineering-entry.md`

- [ ] **Step 1: Write the failing test `tests/scripts/test_new_investigation.sh`**

```sh
#!/usr/bin/env sh
set -eu
SCRIPT="skills/reverse-engineering/new_investigation.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# Run inside a temp dir with a fixed date for determinism.
DIR="$(cd "$TMP" && sh "$OLDPWD/$SCRIPT" demo 2026-01-01)" || fail "non-zero exit"
[ "$DIR" = "docs/reverse/2026-01-01-demo" ] || fail "unexpected path: $DIR"
BASE="$TMP/docs/reverse/2026-01-01-demo"
[ -f "$BASE/00-target.md" ] || fail "00-target.md missing"
[ -f "$BASE/findings.md" ] || fail "findings.md missing"
[ -d "$BASE/artifacts" ] || fail "artifacts/ missing"
[ -d "$BASE/scripts" ] || fail "scripts/ missing"
grep -qi "authorization" "$BASE/00-target.md" || fail "00-target.md missing authorization prompt"

echo "PASS: test_new_investigation.sh"
```

- [ ] **Step 2: Run it — verify it FAILS**

Run: `sh tests/scripts/test_new_investigation.sh`
Expected: FAIL (script missing).

- [ ] **Step 3: Implement `skills/reverse-engineering/new_investigation.sh`**

```sh
#!/usr/bin/env sh
# new_investigation.sh — scaffold a dated investigation folder under docs/reverse/.
# Usage: new_investigation.sh <slug> [YYYY-MM-DD]   (date defaults to today)
# Prints the created directory path (relative).
set -eu
SLUG="${1:?usage: new_investigation.sh <slug> [YYYY-MM-DD]}"
DATE="${2:-$(date +%Y-%m-%d)}"
DIR="docs/reverse/${DATE}-${SLUG}"
mkdir -p "$DIR/artifacts" "$DIR/scripts"

if [ ! -f "$DIR/00-target.md" ]; then
  cat > "$DIR/00-target.md" <<EOF
# 00 — Target — ${SLUG}

- **File:** <path>
- **sha256:** <run: sha256sum / shasum -a 256>
- **Size:** <bytes>
- **Source:** <where it came from>
- **Goal:** <what "done" looks like>

## Authorization / scope
- [ ] I am authorized to analyze this (CTF / owned / authorized engagement).
- Notes: <scope, rules of engagement>

## Dynamic analysis
- Sandbox used (filled in only if the target is ever run): <container / VM>
EOF
fi

[ -f "$DIR/findings.md" ] || printf '# Findings — %s\n\n(append cumulative findings here)\n' "$SLUG" > "$DIR/findings.md"

echo "$DIR"
```

- [ ] **Step 4: Run the test — verify it PASSES**

Run: `sh tests/scripts/test_new_investigation.sh`
Expected: `PASS: test_new_investigation.sh`

- [ ] **Step 5: Write scenario `tests/scenarios/reverse-engineering-entry.md`**

```markdown
# Scenario: entry / orchestration (application + discipline)

**Prompt:** "Here's a file called ./challenge — can you reverse-engineer it?"

**PASS criteria (GREEN, with reverse-engineering):**
- Records authorization/scope (asks or notes it in 00-target.md).
- Ensures tooling — invokes re-preflight if RE tools are missing.
- Runs `new_investigation.sh <slug>` to create `docs/reverse/<date>-<slug>/`.
- Proceeds to triage (re-triage if available; otherwise says triage is the next
  phase) and ends the phase via re-planning's gate.
- Does NOT dump raw decompilation/tool output into the chat.

**Typical RED (baseline, no skill):** starts running tools and pasting raw output
with no investigation folder, no authorization, no plan/gate.
```

- [ ] **Step 6: Author `skills/reverse-engineering/SKILL.md`** to satisfy the contract

Frontmatter (verbatim):

```yaml
---
name: reverse-engineering
description: Use when reverse-engineering or analyzing an unknown binary, executable, firmware image, mobile or managed app, or suspicious file — to start and pilot a structured investigation with reviewed plans. Keywords: reverse engineering, binary analysis, decompile, Ghidra, radare2, CTF, crackme, malware triage, unpack, disassemble, firmware.
---
```

Required contents (the body MUST, and stay < 200 words):
1. One-paragraph overview + the loop (analyze → plan → approve → next → report).
2. First actions: record **authorization/scope**; ensure tooling (**invoke `re-preflight`** if missing); run `new_investigation.sh <slug>` to create the folder.
3. **Routing table:** triage → `re-triage`; after triage, by family — native → `re-static`; firmware/managed/wasm → "pack not built yet; see the roadmap in the spec"; deep analysis → `re-deobfuscate` / `re-solve` / `re-dynamic`; finish → `re-report`.
4. Cross-refs with REQUIRED markers: every phase ends with **`re-planning`** (gate); use **`re-scripting`** when code is needed.
5. The data rule: heavy output → `artifacts/`; summarize into the plan.
6. Relative paths only. (Skills referenced in 3–4 are built in later plans; until then the orchestrator names them and falls back gracefully.)

- [ ] **Step 7: RED/GREEN test the skill** with `reverse-engineering-entry.md`. Close loopholes; re-run.

- [ ] **Step 8: Commit**

```sh
git add skills/reverse-engineering tests/scripts/test_new_investigation.sh tests/scenarios/reverse-engineering-entry.md
git commit -m "Plan1 T6: reverse-engineering orchestrator + new_investigation.sh"
```

---

## Task 7: End-to-end dry run + Plan-1 wrap-up

**Files:**
- Modify: `README.md` (mark spine as built)

- [ ] **Step 1: Run all script tests**

```sh
sh tests/scripts/test_preflight.sh
sh tests/scripts/test_new_investigation.sh
python3 -m pytest tests/scripts/test_script_template.py -q
```
Expected: all PASS / `3 passed`.

- [ ] **Step 2: Install into a scratch skills dir and confirm discovery**

```sh
DEST="$(mktemp -d)"; for d in skills/*/; do cp -r "$d" "$DEST/"; done
ls "$DEST"   # expect: re-planning re-preflight re-scripting reverse-engineering
# sanity: each has a SKILL.md with name == dir
for d in "$DEST"/*/; do grep -q "name: $(basename "$d")" "$d/SKILL.md" || echo "BAD name: $d"; done
```
Expected: four skill dirs, no "BAD name" output.

- [ ] **Step 3: Manual harness dry run (in-agent)**

In a fresh agent session with the skills installed, prompt: *"Reverse-engineer ./challenge"* (any throwaway file). Confirm: authorization recorded → preflight offered/run → `docs/reverse/<date>-challenge/` created → it heads to triage and stops at a plan gate. Note any rough edges as issues (do not fix here; fold into Plan 2 or a follow-up).

- [ ] **Step 4: Update `README.md` status line**

Change the Status line to: `v1 spine built (orchestrator, preflight, planning+self-review gate, scripting). Native phases next.`

- [ ] **Step 5: Commit**

```sh
git add README.md
git commit -m "Plan1 T7: end-to-end dry run; mark spine built"
```

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 1 slice):** orchestrator §4a ✓ (T6); preflight + artifacts §7 ✓ (T3); planning + self-review + gate §6/§4d ✓ (T4); scripting + template §8 ✓ (T5); packaging + dual-agent install §11/§11a ✓ (T1); portability rules ✓ (T1 agent-tools); skill-testing method §10 ✓ (T2 + per-skill RED/GREEN). Deferred phases/fixtures/references explicitly belong to Plans 2–4 (stated in header).
- **Placeholders:** none — every script/test/template/prompt/scaffold is complete; SKILL.md bodies have verbatim frontmatter + an explicit required-contents contract + committed RED/GREEN scenarios (authored via `superpowers:writing-skills` at execution, per the header note).
- **Type/name consistency:** skill names match directory names everywhere (`reverse-engineering`, `re-preflight`, `re-planning`, `re-scripting`); `new_investigation.sh` prints `docs/reverse/<date>-<slug>` and the test asserts that exact path; `preflight.sh` writes `install.sh` + `Dockerfile.snippet` and its test checks those names; `script_template.py` exposes `solve()` + `--help` matching its test.
```
