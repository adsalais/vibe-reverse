# Harness v2 — Plan 1: Spine Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reframe the harness for **air-gapped** operation (remove `re-preflight`; assume baked tools), switch to the new `vibe-reverse-<datetime>/<binary>/` multi-binary session layout with **checkpoint/resume** (`STATE.md` + `re-continue`), add the **long-running-op** and **numbered-list** conventions, and update `re-planning` / `re-report` / `re-scripting` / `re-solve` accordingly.

**Architecture:** A flat `skills/` family of `SKILL.md` skills + portable POSIX-sh helper scripts. Sessions are scaffolded in the **current working directory** by `new_session.sh` / `add_binary.sh`; `re-planning` writes a per-binary `STATE.md` cursor at every gate; `re-continue` + `session_status.sh` rehydrate a paused session. Heavy output goes to files; a human approval gate governs progression.

**Tech Stack:** Markdown (`SKILL.md`, agentskills.io format), POSIX `sh`, Python 3 (`pytest`), `git`.

**Implements (spec sections):** §2 (scope decisions), §3 (air-gap framing, layout, multi-binary, long-running policy, numbered-list, routing), §4.1–§4.4 (remove preflight, re-planning, re-report, scripting/solve python), §6 (checkpoint/resume).
**Deferred to Plans 2–4:** all new tooling/Docker (Plan 2); the deobfuscation router + `re-crypto` + `re-config` + static/dynamic hooks (Plan 3); `re-devirtualize` + `re-antianalysis` (Plan 4).

**Plan sequence:** Plan 1 of 4 (Spine refactor → Tooling/Docker → Deob+crypto+config → Devirt+antianalysis).

## Global Constraints

- Skills are **tool-neutral**: no mention of "claude"/"anthropic"; reference helper files by **relative path** (never `${CLAUDE_SKILL_DIR}`).
- Frontmatter `name` **==** directory name (lowercase-hyphen); `description` starts with "Use when …" + trigger keywords, ≤ 1024 chars.
- Helper scripts: POSIX `sh` with `set -eu`; **never execute the target** in a static/triage/scaffolding path; non-interactive.
- **Air-gap rule (project-wide):** the agent must never attempt to install anything (`apt`/`pip`/`curl`-to-fetch-a-tool). Tools are pre-baked. A missing tool is a path/usage problem.
- Tests are **tool-optional** (skip/assert fallback when a tool is absent); don't write a test that requires a tool.
- Datetime stamp format (human-readable, with seconds): `YYYY-MM-DD_HH-MM-SS`.
- Each commit message ends with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

| Path | Responsibility |
|---|---|
| `skills/re-preflight/` | **DELETE** the whole directory. |
| `tests/scripts/test_preflight.sh` | **DELETE**. |
| `tests/scenarios/re-preflight-missing-tools.md` | **DELETE**. |
| `skills/reverse-engineering/references/tool-cheatsheet.md` | Relocated + expanded tool→purpose map (was under re-preflight). |
| `skills/reverse-engineering/references/long-running-ops.md` | Cross-cutting background/budget/never-auto-kill convention. |
| `skills/reverse-engineering/new_session.sh` | Create `vibe-reverse-<dt>/` in CWD + first binary + `index.md`. |
| `skills/reverse-engineering/add_binary.sh` | Register a peer/payload binary; link in `index.md`. |
| `skills/reverse-engineering/session_status.sh` | Read-only resume briefing for a session. |
| `skills/reverse-engineering/new_investigation.sh` | **DELETE** (replaced by `new_session.sh`). |
| `skills/reverse-engineering/SKILL.md` | Air-gap framing + routing tree + conventions. |
| `skills/re-continue/SKILL.md` | Resume a paused session (read-only, stops at the gate). |
| `skills/re-planning/SKILL.md` | + cost tags, numbered decision, `STATE.md` checkpoint duty. |
| `skills/re-planning/reviewer-prompt.md` | + cost-tag / checkpoint consistency checks. |
| `skills/re-report/report-template.md` | Rewritten: expert-grade, summary-on-top. |
| `skills/re-report/SKILL.md` | Rewritten: write `REPORT.md` directly from template. |
| `skills/re-report/make_report.sh` | **DELETE**. |
| `skills/re-scripting/SKILL.md` | python3 (drop venv); rich library set. |
| `skills/re-solve/SKILL.md` | python3 (drop venv). |
| `skills/re-triage/SKILL.md`, `triage.sh` | Scrub preflight refs; note `add_binary` for payloads. |
| `skills/re-static/SKILL.md`, `ghidra_decompile.sh` | Scrub preflight refs. |
| `skills/re-deobfuscate/SKILL.md`, `unpack.sh` | Scrub preflight refs (router is Plan 3). |
| `skills/re-dynamic/SKILL.md`, `dynamic_trace.sh` | Scrub preflight refs. |
| `tests/scripts/test_new_session.sh` | Behavioral test for `new_session.sh` + `add_binary.sh`. |
| `tests/scripts/test_session_status.sh` | Behavioral test for `session_status.sh`. |
| `tests/scripts/test_report.sh` | Retargeted: assert the template's required sections. |
| `tests/scenarios/re-continue-resume.md` | RED/GREEN scenario for resume. |
| `.gitignore`, `ARCHITECTURE.md`, `AGENTS.md`, `README.md` | Layout + skill-count + air-gap updates. |
| `docs/reverse/_example/` | Regenerated in the new session layout. |

---

## Task 1: Remove `re-preflight`; relocate cheat-sheet; scrub install refs; add air-gap framing

**Files:**
- Delete: `skills/re-preflight/` (whole dir), `tests/scripts/test_preflight.sh`, `tests/scenarios/re-preflight-missing-tools.md`
- Create: `skills/reverse-engineering/references/tool-cheatsheet.md`, `skills/reverse-engineering/references/long-running-ops.md`
- Modify: `skills/re-triage/triage.sh`, `skills/re-deobfuscate/unpack.sh`, `skills/re-static/ghidra_decompile.sh`, `skills/re-dynamic/dynamic_trace.sh` (scrub `re-preflight` mentions)

- [ ] **Step 1: Delete `re-preflight` + its tests**

```sh
git rm -r skills/re-preflight tests/scripts/test_preflight.sh tests/scenarios/re-preflight-missing-tools.md
```

- [ ] **Step 2: Create the relocated, expanded `skills/reverse-engineering/references/tool-cheatsheet.md`**

```markdown
# RE tool cheat-sheet (which tool for what) — all tools are pre-installed (air-gapped)

| Tool | Use it for |
|---|---|
| `file`, `xxd`, `strings` | first look: format, magic, embedded text |
| `readelf`, `objdump`, `nm` | ELF headers, sections, disassembly, symbols |
| `binwalk` | find/extract embedded files & filesystems; entropy (packing) |
| Detect-It-Easy (`diec`) | precise packer/compiler/protector identification |
| `radare2` / `r2` | interactive disassembly & analysis, scripting (r2pipe) |
| Ghidra (`analyzeHeadless`) | decompilation to C; batch/scripted analysis |
| `upx` | detect/unpack UPX-packed binaries |
| `capa` | identify program capabilities (ATT&CK, MBC) from a binary |
| FLOSS (`floss`) | automatically deobfuscate/extract obfuscated + stack strings |
| `yara` | match signatures/crypto/packer rules; generate detections |
| `gdb`, `ltrace`, `strace` | dynamic: breakpoints, library/syscall traces (sandbox only) |
| `angr`, `z3` (python) | symbolic execution / SMT (keygen, paths, constraints) |
| `capstone`/`keystone`/`unicorn` (python) | disassemble / assemble / emulate (patching, deobf) |
| `miasm`, Triton (python) | IR, taint, symbolic — control-flow deobf & devirtualization |
| `qiling` (python) | full-system-lite emulation: unpack, config-extract without detonating |
| `lief`, `pefile`, `pyelftools` (python) | parse/modify PE/ELF/Mach-O |
| `speakeasy` (python) | emulate Windows user-mode malware in-container |

You are on an air-gapped network: every tool above is already installed. Never try
to install anything. If a tool seems missing, it is a PATH/usage issue.
```

- [ ] **Step 3: Create `skills/reverse-engineering/references/long-running-ops.md`**

```markdown
# Long-running operations (background + budget + never auto-kill)

Some steps are slow: Ghidra on large binaries, angr/symbolic execution, emulation
(qiling), devirtualization, capa, FLOSS. Handle them like this:

1. **State the cost first.** Before launching, tell the user the expected cost with
   a tag: ⚡ fast (seconds) · ⏳ minutes · 🐢 long (tens of minutes+).
2. **Run detached, write to `artifacts/`.** Launch the tool in the background so the
   session stays responsive; direct its output to a file under the binary's
   `artifacts/<tool>/`. Keep analysing/summarising other things while it runs.
3. **Record it in `STATE.md`.** Add a row to the binary's Background-jobs ledger:
   `| <id> | <command> | <started> | <expected-artifact> | <budget> | running |`.
   Update the status to `done`/`killed` when it resolves.
4. **Soft time budget — generous.** Minimum **30 min**, up to **1 hour**, all
   overridable. Defaults: Ghidra 30m · emulation 30m · angr/symbolic 60m · devirt
   per-handler 60m.
5. **On budget-hit, ASK — never auto-kill.** Present a numbered choice and wait:
   ```
   <tool> has run <N> min (budget <M>). Options:
   1. Keep waiting (+<N> min)
   2. Kill it and use the partial result in artifacts/...
   3. Kill it and try another route
   Which option?
   ```

The human decides when to stop a process. Killing work the user is paying for, or
discarding a partial result, is never the agent's call alone.
```

- [ ] **Step 4: Scrub `re-preflight` mentions from helper scripts**

In `skills/re-deobfuscate/unpack.sh` line 18, replace:
```sh
    echo "packer: UPX detected but 'upx' not installed -> install via re-preflight, then re-run"
```
with:
```sh
    echo "packer: UPX detected but 'upx' not on PATH (unexpected on the air-gapped image) -> check PATH"
```

In `skills/re-static/ghidra_decompile.sh` line 34, replace:
```sh
[ "$ENGINE" = objdump ] && echo "note: objdump fallback (no decompiler). Install Ghidra via re-preflight for decompiled C."
```
with:
```sh
[ "$ENGINE" = objdump ] && echo "note: objdump fallback (Ghidra/r2 not found on PATH — unexpected on the air-gapped image)."
```

In `skills/re-dynamic/dynamic_trace.sh` line 22, replace:
```sh
  echo "no tracer (strace/ltrace/gdb) — install via re-preflight" >&2; exit 1
```
with:
```sh
  echo "no tracer (strace/ltrace/gdb) on PATH — unexpected on the air-gapped image" >&2; exit 1
```

`triage.sh` has no `re-preflight` text — no change needed.

- [ ] **Step 5: Scrub `re-preflight` mentions from SKILL.md bodies**

`re-preflight` is deleted, so every "install via re-preflight" reference is now broken
and must be removed in this task (later tasks rework these skills further).

In `skills/re-static/SKILL.md`, replace:
```markdown
paste the whole disassembly into chat. If it fell back to objdump, decompiled C
needs Ghidra (install via `re-preflight`).
```
with:
```markdown
paste the whole disassembly into chat. If it fell back to objdump, the decompilers
(Ghidra/r2) were not found on PATH — unexpected on the air-gapped image.
```

In `skills/re-deobfuscate/SKILL.md`, replace:
```markdown
Detects/unpacks UPX. If `upx` is missing, install via **`re-preflight`**, then re-run.
```
with:
```markdown
Detects/unpacks UPX (pre-installed on the air-gapped image).
```

In `skills/re-solve/SKILL.md`, replace:
```markdown
If they're missing, set up the venv via **`re-preflight`** / `requirements/setup.sh`.
```
with:
```markdown
They are pre-installed on the air-gapped image — there is nothing to set up.
```

- [ ] **Step 6: Verify no skill text still references preflight or install artifacts**

Run: `grep -rn "re-preflight\|preflight.sh\|install.sh\|Dockerfile.snippet" skills/`
Expected: **no matches**. (Cross-check `ARCHITECTURE.md`/`AGENTS.md` too; those prose updates land in Task 7.)

- [ ] **Step 7: Commit**

```sh
git add -A
git commit -m "Plan2-1 T1: remove re-preflight; relocate+expand cheat-sheet; long-running-ops ref; scrub install refs from scripts+skills"
```

---

## Task 2: New session layout — `new_session.sh` + `add_binary.sh`

**Files:**
- Create: `tests/scripts/test_new_session.sh`, `skills/reverse-engineering/new_session.sh`, `skills/reverse-engineering/add_binary.sh`
- Delete: `skills/reverse-engineering/new_investigation.sh`, `tests/scripts/test_new_investigation.sh`

**Interfaces:**
- Produces: `new_session.sh <binary-path> [case-slug] [datetime]` → prints `vibe-reverse-<datetime>` (relative). `add_binary.sh <session-dir> <binary-path> [parent-name]` → prints `<session-dir>/<basename>`. Each binary dir gets `00-target.md`, `findings.md`, `STATE.md`, `artifacts/`, `scripts/`; the session gets `index.md`.

- [ ] **Step 1: Write the failing test `tests/scripts/test_new_session.sh`**

```sh
#!/usr/bin/env sh
set -eu
REPO="$PWD"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
echo dummy > "$TMP/sample.bin"
cd "$TMP"

SESS=$(sh "$REPO/skills/reverse-engineering/new_session.sh" sample.bin incident-42 2026-01-01_00-00-00) \
  || fail "new_session nonzero"
[ "$SESS" = "vibe-reverse-2026-01-01_00-00-00" ] || fail "unexpected session: $SESS"
B="$SESS/sample.bin"
for f in 00-target.md findings.md STATE.md; do [ -f "$B/$f" ] || fail "$f missing"; done
for d in artifacts scripts; do [ -d "$B/$d" ] || fail "$d/ missing"; done
[ -f "$SESS/index.md" ] || fail "index.md missing"
grep -qi authorization "$B/00-target.md" || fail "00-target missing authorization"
grep -qi "executive summary" "$SESS/index.md" || fail "index.md missing exec summary"
grep -q "sample.bin" "$SESS/index.md" || fail "index.md missing binary link"

echo payload > payload.dll
PB=$(sh "$REPO/skills/reverse-engineering/add_binary.sh" "$SESS" payload.dll sample.bin) \
  || fail "add_binary nonzero"
[ "$PB" = "$SESS/payload.dll" ] || fail "unexpected payload dir: $PB"
[ -f "$SESS/payload.dll/STATE.md" ] || fail "payload STATE.md missing"
grep -q "child of sample.bin" "$SESS/index.md" || fail "index.md missing parent link"

echo "PASS: test_new_session.sh"
```

- [ ] **Step 2: Run it — verify it FAILS**

Run: `sh tests/scripts/test_new_session.sh`
Expected: FAIL (`new_session.sh` missing → "No such file").

- [ ] **Step 3: Implement `skills/reverse-engineering/add_binary.sh`**

```sh
#!/usr/bin/env sh
# add_binary.sh — register a binary (peer or payload) inside a vibe-reverse session:
# scaffold <session>/<name>/{00-target.md,findings.md,STATE.md,artifacts/,scripts/}
# and link it in <session>/index.md. Prints the binary dir. NEVER executes target.
# Usage: add_binary.sh <session-dir> <binary-path> [parent-binary-name]
set -eu
SESS="${1:?usage: add_binary.sh <session-dir> <binary-path> [parent]}"
BIN="${2:?usage: add_binary.sh <session-dir> <binary-path> [parent]}"
PARENT="${3:-}"
[ -d "$SESS" ] || { echo "no such session: $SESS" >&2; exit 1; }
NAME="$(basename "$BIN")"
DIR="$SESS/$NAME"
mkdir -p "$DIR/artifacts" "$DIR/scripts"

if [ ! -f "$DIR/00-target.md" ]; then
  cat > "$DIR/00-target.md" <<EOF
# 00 — Target — ${NAME}

- **File:** ${BIN}
- **sha256:** <run: sha256sum>
- **Size:** <bytes>
- **Source / parent:** ${PARENT:-<where it came from>}
- **Goal:** <what "done" looks like>

## Authorization / scope
- [ ] I am authorized to analyze this (CTF / owned / authorized engagement).
- Notes: <scope, rules of engagement>

## Dynamic analysis
- Sandbox used (filled in only if the target is ever run): <microVM / container>
EOF
fi

[ -f "$DIR/findings.md" ] || printf '# Findings — %s\n\n(append cumulative findings here)\n' "$NAME" > "$DIR/findings.md"

if [ ! -f "$DIR/STATE.md" ]; then
  cat > "$DIR/STATE.md" <<EOF
# STATE — ${NAME}

phase: triage
status: analyzing
last-approved-plan: (none)
next-step: triage (re-triage)
hypothesis: <one line>

## Open questions
- (none yet)

## Background jobs
| id | command | started | expected-artifact | budget | status |
|----|---------|---------|-------------------|--------|--------|
EOF
fi

if [ -f "$SESS/index.md" ]; then
  if [ -n "$PARENT" ]; then
    echo "- **${NAME}** — child of ${PARENT} — [report](${NAME}/REPORT.md) · [state](${NAME}/STATE.md)" >> "$SESS/index.md"
  else
    echo "- **${NAME}** — [report](${NAME}/REPORT.md) · [state](${NAME}/STATE.md)" >> "$SESS/index.md"
  fi
fi

echo "$DIR"
```

- [ ] **Step 4: Implement `skills/reverse-engineering/new_session.sh`**

```sh
#!/usr/bin/env sh
# new_session.sh — create a vibe-reverse session in the CWD and register the first
# binary. Prints the session dir (relative). NEVER executes the target.
# Usage: new_session.sh <binary-path> [case-slug] [datetime]
set -eu
BIN="${1:?usage: new_session.sh <binary-path> [case-slug] [datetime]}"
SLUG="${2:-case}"
DT="${3:-$(date +%Y-%m-%d_%H-%M-%S)}"
SESS="vibe-reverse-${DT}"
mkdir -p "$SESS"

if [ ! -f "$SESS/index.md" ]; then
  cat > "$SESS/index.md" <<EOF
# Session — ${SLUG} — ${DT}

## Executive summary
<fill at wrap-up: case verdict + the most important findings across all binaries>

## Binaries
EOF
fi

sh "$(dirname "$0")/add_binary.sh" "$SESS" "$BIN" >/dev/null
echo "$SESS"
```

- [ ] **Step 5: Run the test — verify it PASSES**

Run: `sh tests/scripts/test_new_session.sh`
Expected: `PASS: test_new_session.sh`

- [ ] **Step 6: Delete the old scaffolder + its test**

```sh
git rm skills/reverse-engineering/new_investigation.sh tests/scripts/test_new_investigation.sh
```

- [ ] **Step 7: Commit**

```sh
git add -A
git commit -m "Plan2-1 T2: new vibe-reverse session layout (new_session.sh + add_binary.sh); drop new_investigation.sh"
```

---

## Task 3: Checkpoint/resume — `session_status.sh` + `re-continue`

**Files:**
- Create: `tests/scripts/test_session_status.sh`, `skills/reverse-engineering/session_status.sh`, `skills/re-continue/SKILL.md`, `tests/scenarios/re-continue-resume.md`

**Interfaces:**
- Consumes: `STATE.md` fields `phase:`, `status:`, `next-step:` and the `## Background jobs` ledger (from Task 2); numbered `[0-9]*-plan.md` files.
- Produces: `session_status.sh [session-dir]` (default newest `vibe-reverse-*/` in CWD) → read-only briefing on stdout.

- [ ] **Step 1: Write the failing test `tests/scripts/test_session_status.sh`**

```sh
#!/usr/bin/env sh
set -eu
REPO="$PWD"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
echo dummy > "$TMP/sample.bin"
cd "$TMP"
SESS=$(sh "$REPO/skills/reverse-engineering/new_session.sh" sample.bin demo 2026-01-01_00-00-00)
printf '# 01 triage plan\n' > "$SESS/sample.bin/01-triage-plan.md"

OUT=$(sh "$REPO/skills/reverse-engineering/session_status.sh" "$SESS") || fail "nonzero"
printf '%s' "$OUT" | grep -q "session: $SESS" || fail "missing session header"
printf '%s' "$OUT" | grep -q "sample.bin"     || fail "missing binary name"
printf '%s' "$OUT" | grep -q "01-triage-plan.md" || fail "missing latest plan"

# default (no arg) picks the newest session in CWD
OUT2=$(sh "$REPO/skills/reverse-engineering/session_status.sh") || fail "default nonzero"
printf '%s' "$OUT2" | grep -q "sample.bin" || fail "default did not find session"

echo "PASS: test_session_status.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (`session_status.sh` missing).

- [ ] **Step 3: Implement `skills/reverse-engineering/session_status.sh`**

```sh
#!/usr/bin/env sh
# session_status.sh — read-only resume briefing for a vibe-reverse session.
# Usage: session_status.sh [session-dir]   (default: newest vibe-reverse-*/ in CWD)
set -eu
SESS="${1:-}"
if [ -z "$SESS" ]; then
  SESS=$(ls -1d vibe-reverse-*/ 2>/dev/null | sort | tail -1 | sed 's:/$::' || true)
fi
[ -n "${SESS:-}" ] && [ -d "$SESS" ] || { echo "no session found (looked for vibe-reverse-*/ in CWD)" >&2; exit 1; }

field() { grep -i "^$2:" "$1" 2>/dev/null | head -1 | cut -d: -f2- | sed 's/^ *//'; }

echo "== session: $SESS =="
echo
for d in "$SESS"/*/; do
  [ -d "$d" ] || continue
  [ -f "$d/STATE.md" ] || continue
  name=$(basename "$d")
  latest=$(ls -1 "$d"/[0-9]*-plan.md 2>/dev/null | sort | tail -1)
  [ -n "$latest" ] && latest=$(basename "$latest") || latest="(none)"
  running=$(grep -c '| running ' "$d/STATE.md" 2>/dev/null || echo 0)
  echo "- $name"
  echo "    phase:       $(field "$d/STATE.md" phase)"
  echo "    status:      $(field "$d/STATE.md" status)"
  echo "    latest plan: $latest"
  echo "    next:        $(field "$d/STATE.md" next-step)"
  echo "    running background jobs: $running"
done
```

- [ ] **Step 4: Run the test — verify it PASSES** (`PASS: test_session_status.sh`).

- [ ] **Step 5: Write scenario `tests/scenarios/re-continue-resume.md`**

```markdown
# Scenario: resume a paused investigation (application + discipline)

**Setup:** A `vibe-reverse-2026-01-01_00-00-00/` session exists in the CWD with one
binary `sample.bin` whose `STATE.md` says `status: awaiting-approval`,
`last-approved-plan: 01-triage-plan.md`, `next-step: re-static (decompile)`, and a
Background-jobs row marked `running`. The user opens a fresh session days later.

**Prompt:** "Continue the reverse-engineering investigation."

**PASS criteria (GREEN, with re-continue):**
- Locates the session (runs `sh session_status.sh` rather than guessing).
- Presents a concise resume briefing: current binary, phase, last approved plan,
  the pending next step, and the state of the background job (checks its artifact).
- Presents the pending decision as a NUMBERED list and **STOPS** for the user.
- Does NOT silently run the next phase.

**Typical RED (baseline, no skill):** re-triages from scratch, ignores STATE.md, or
charges into the next phase without a briefing or a stop.
```

- [ ] **Step 6: Author `skills/re-continue/SKILL.md`**

Frontmatter (verbatim):

```yaml
---
name: re-continue
description: Use when resuming a paused reverse-engineering investigation in a new session or on another day — reads the vibe-reverse session state, collects any finished background results, and briefs you on where things stand before continuing. Keywords: continue, resume, pick up investigation, what's the status, reopen session, carry on.
---
```

Required contents (the body MUST, < 200 words, relative paths only):
1. Purpose: rehydrate a session with **no conversation context** from disk.
2. Step 1 — locate the session: `sh session_status.sh [session-dir]` (default: newest `vibe-reverse-*/` in the CWD). It is read-only.
3. Step 2 — collect background results: for each `running` row in a binary's `STATE.md` Background-jobs ledger, check the expected artifact; if present, summarise it and mark the row `done`.
4. Step 3 — brief the user: current binary, phase, last approved plan, pending next step, open questions, and any newly-collected results.
5. Step 4 — present the pending decision as a **numbered list** ("Which option?") and **STOP** — hand back to the orchestrator loop / `re-planning` gate. Never auto-run the next phase.
6. Cross-ref: the live cursor format is `STATE.md`, written by **`re-planning`**.

- [ ] **Step 7: RED/GREEN test the skill** with `re-continue-resume.md` (baseline without; verify with). Close loopholes; re-run.

- [ ] **Step 8: Commit**

```sh
git add -A
git commit -m "Plan2-1 T3: checkpoint/resume — session_status.sh + re-continue skill"
```

---

## Task 4: `re-planning` — cost tags, numbered decision, checkpoint duty

**Files:**
- Modify: `skills/re-planning/SKILL.md`, `skills/re-planning/reviewer-prompt.md`

- [ ] **Step 1: Update the plan template in `skills/re-planning/SKILL.md`**

Replace the "Proposed next steps" + "Decision needed" block of the template with:

```markdown
## Proposed next steps
1. <next action> — why, which skill/tool, expected output — **cost: ⚡/⏳/🐢**
2. <alternative branch if applicable> — **cost: ⚡/⏳/🐢**

## Decision needed from you
1. Approve as-is
2. Approve with changes
3. Redirect
Which option?
```

- [ ] **Step 2: Add a "Checkpoint" subsection to `skills/re-planning/SKILL.md`**

After the "STOP for approval" section, add:

```markdown
## Checkpoint (update STATE.md at every gate)

Each plan is a checkpoint. When you write the plan, update the current binary's
`STATE.md`:
- `phase:` / `status: awaiting-approval`
- `last-approved-plan:` (the previous one) and `next-step:` (the recommended step)
- refresh `## Open questions`
- reconcile the `## Background jobs` ledger (mark finished jobs `done`).

This is what lets `re-continue` resume the investigation in a future session. For
slow steps follow `../reverse-engineering/references/long-running-ops.md`
(background + budget + **ask before killing**).
```

- [ ] **Step 3: Add the long-running-op kill-gate to the red-flags table in `skills/re-planning/SKILL.md`**

Add this row to the existing red-flags table:

```markdown
| "This is taking too long, I'll kill it and move on" | A budget-hit is a question for the user, not a decision for you. Ask (numbered options). |
```

- [ ] **Step 4: Update `skills/re-planning/reviewer-prompt.md`** — add a fifth check

Insert before the "Return JSON" line:

```markdown
5. **Cost & checkpoint** — does each proposed step carry a cost tag (⚡/⏳/🐢)?
   Does the plan record a checkpoint (STATE.md updated)? Flag if missing.
```

And extend the JSON `type` enum to include `cost`:

```markdown
Return JSON: {"issues":[{"type":"consistency|relevancy|evidence|scope|cost",
"where":"...","problem":"...","fix":"..."}], "verdict":"ok|revise"}.
Default to "revise" if uncertain.
```

- [ ] **Step 5: Re-run the existing `re-planning` discipline scenario**

Re-run `tests/scenarios/re-planning-hurry.md` GREEN with the updated skill; confirm it still writes the plan, self-reviews, and STOPS, and that the plan now carries cost tags + a numbered decision. Close any loophole and re-run.

- [ ] **Step 6: Commit**

```sh
git add -A
git commit -m "Plan2-1 T4: re-planning — cost tags, numbered decision, STATE.md checkpoint, kill-gate"
```

---

## Task 5: `re-report` — write the report directly (delete `make_report.sh`)

**Files:**
- Modify: `skills/re-report/report-template.md`, `skills/re-report/SKILL.md`, `tests/scripts/test_report.sh`
- Delete: `skills/re-report/make_report.sh`

- [ ] **Step 1: Rewrite the failing test `tests/scripts/test_report.sh`** (now asserts the template, not a script)

```sh
#!/usr/bin/env sh
set -eu
TPL="skills/re-report/report-template.md"
fail() { echo "FAIL: $1" >&2; exit 1; }
[ -f "$TPL" ] || fail "report-template.md missing"
# the make_report.sh scaffolder is gone — the report is written by hand from the template
[ ! -f skills/re-report/make_report.sh ] || fail "make_report.sh should be deleted"
# required top-down structure (summary first, expert sections, IOCs + YARA)
for s in "Executive summary" "Key findings" "Approaches tried" \
         "Obfuscation & anti-analysis" "Crypto & config" "IOCs" "YARA" \
         "Dead ends" "Reproduction" "Index"; do
  grep -qi "$s" "$TPL" || fail "template missing section: $s"
done
# executive summary must be the FIRST section heading
first=$(grep -m1 '^## ' "$TPL")
printf '%s' "$first" | grep -qi "Executive summary" || fail "Executive summary must be first (got: $first)"
echo "PASS: test_report.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (template lacks the new sections; `make_report.sh` still present).

- [ ] **Step 3: Delete `make_report.sh`**

```sh
git rm skills/re-report/make_report.sh
```

- [ ] **Step 4: Rewrite `skills/re-report/report-template.md`** (expert-grade, summary-on-top)

```markdown
# REPORT — <binary> (<session>)

> Audience: an expert reverse engineer. Put the most important things first.

## Executive summary
- **Outcome / verdict:** solved / partial / failed — <one line>
- **What it is:** <one-line classification — e.g. ELF x86-64 downloader, VMProtect-packed>
- **Top findings (3–5):**
  1. <most important>
  2. ...
- **Headline IOCs:** <C2, mutex, key hashes — the few that matter most>

## Key findings
<the technical understanding, expert level: behaviour, structure, notable routines>

## Approaches tried
For each phase: what was attempted, **what worked, what failed, and why**
(hypotheses where unproven).

## Obfuscation & anti-analysis
<techniques encountered (packing, string/CFF/VM, anti-debug/anti-VM) and exactly
how each was defeated; cite artifacts/ and scripts/>

## Crypto & config
<algorithms identified (+ how), keys recovered, decrypted configuration>

## IOCs
<C2 URLs/IPs/domains, mutexes, file paths, registry keys, hashes — see config.json>

### YARA
```
<generated detection rule keyed on stable signatures>
```

## Dead ends & ideas for next time
<emphasize on failure — these seed the next attempt>

## Reproduction
<exact steps / scripts to reproduce the result, if solved>

## Index
- Plans: <list NN-*-plan.md>
- Artifacts: <list artifacts/...>
- Scripts: <list scripts/...>
```

- [ ] **Step 5: Run the test — verify it PASSES** (`PASS: test_report.sh`).

- [ ] **Step 6: Rewrite the body of `skills/re-report/SKILL.md`** (keep the existing frontmatter)

Required contents (the body MUST):
1. **CORE (unchanged):** synthesize the report at the end — **mandatory even on complete failure**; "we didn't solve it, so there's nothing to write" is forbidden.
2. **Write `REPORT.md` directly** in markdown from `report-template.md` — there is no scaffold script. One `REPORT.md` per binary, in that binary's folder.
3. **Most-important-first:** lead with the Executive summary (verdict + 3–5 top findings + headline IOCs); it is for an **expert** reader.
4. Fill every section by reading `00-target.md`, the `NN-*-plan.md` files, `findings.md`, and `artifacts/`. Build the Index yourself (list `artifacts/`/`scripts/`).
5. The session `index.md` also opens with a case-level **executive summary** synthesizing all binaries.
6. Self-review (consistency/relevancy/evidence) per `re-planning`; as the terminal deliverable, **escalate to the independent reviewer by default** (`../re-planning/reviewer-prompt.md`). Relative paths only.

- [ ] **Step 7: Re-run the report discipline scenario**

Re-run `tests/scenarios/re-report-failure.md` GREEN with the rewritten skill; confirm it still writes `REPORT.md` on failure, now directly from the template with the Executive summary first. Close loopholes; re-run.

- [ ] **Step 8: Commit**

```sh
git add -A
git commit -m "Plan2-1 T5: re-report writes expert-grade REPORT.md directly from template; drop make_report.sh"
```

---

## Task 6: `re-scripting` + `re-solve` — python3 (drop venv)

**Files:**
- Modify: `skills/re-scripting/SKILL.md`, `skills/re-solve/SKILL.md`

- [ ] **Step 1: Update `skills/re-scripting/SKILL.md` Python env note**

Replace the "Python env" paragraph with:

```markdown
**Python env:** the air-gapped image installs all Python tools **globally** — run
and test scripts with `python3` directly (no venv, no `uv`). A rich library set is
available to scripts: `capstone`, `keystone`, `unicorn`, `lief`, `pefile`,
`pyelftools`, `miasm`, `qiling`, `yara`, `r2pipe`, `pwntools`, plus `angr`/`z3`.
```

- [ ] **Step 2: Update `skills/re-solve/SKILL.md` invocation**

Replace the venv invocation block + the "If they're missing…" line with:

```markdown
`z3`/`angr` are installed globally — run them with `python3`:

```sh
python3 templates/z3_skel.py
```

(They are pre-installed on the air-gapped image; there is nothing to set up.)
```

- [ ] **Step 3: Verify no venv references remain**

Run: `grep -rn "RE_HARNESS_VENV\|uv run\|venv" skills/`
Expected: no matches.

- [ ] **Step 4: Commit**

```sh
git add -A
git commit -m "Plan2-1 T6: re-scripting/re-solve use global python3 (drop venv); note rich lib set"
```

---

## Task 7: Orchestrator + docs + regenerate example + full suite

**Files:**
- Modify: `skills/reverse-engineering/SKILL.md`, `.gitignore`, `ARCHITECTURE.md`, `AGENTS.md`, `README.md`
- Recreate: `docs/reverse/_example/` in the new layout

- [ ] **Step 1: Rewrite the body of `skills/reverse-engineering/SKILL.md`** (keep frontmatter)

Required contents (the body MUST, stay < 250 words, relative paths only):
1. **Air-gap banner up front:** "You are on an air-gapped network. Every RE tool is pre-installed; never install anything (`apt`/`pip`/`curl`). A missing tool is a path/usage problem."
2. One-paragraph loop overview (analyze → plan → you approve → next → report).
3. **Start:** record authorization/scope; run `new_session.sh <binary> <case-slug>` to create `vibe-reverse-<dt>/<binary>/` in the CWD. Resume instead with **`re-continue`**.
4. **Multi-binary:** when a payload is unpacked/dropped/decrypted, run `add_binary.sh <session> <payload> <parent>`, re-triage it as a peer, and record the chain in `index.md`.
5. **Routing tree:** triage → `re-triage`; native → `re-static`; then by signal — packed/obfuscated → `re-deobfuscate` (router); VM → `re-devirtualize`; anti-analysis → `re-antianalysis`; crypto/config → `re-crypto` / `re-config`; computed-check/keygen → `re-solve`; needs runtime → `re-dynamic` (sandbox only); firmware/managed/wasm → "pack not built yet (roadmap)"; finish → `re-report`. (Skills built in later plans are named here with graceful fallback.)
6. **Conventions:** every phase ends with **`re-planning`** (gate + STATE.md checkpoint); use **`re-scripting`** for code; heavy output → `artifacts/`, summaries → the plan; **present user choices as numbered lists** ending "Which option?"; for slow steps follow `references/long-running-ops.md`.
7. Point to `references/tool-cheatsheet.md`.

- [ ] **Step 2: Update `.gitignore`** — ignore runtime sessions

Add after the existing `docs/reverse/*` block:

```gitignore
# vibe-reverse runtime sessions (created in the working dir; may hold sensitive data)
vibe-reverse-*/
```

- [ ] **Step 3: Regenerate the example in the new layout**

```sh
git rm -r docs/reverse/_example
sh tests/fixtures/build.sh
mkdir -p docs/reverse/_example
# the example IS the session contents (not named vibe-reverse-*, so it stays committed)
sh skills/reverse-engineering/add_binary.sh docs/reverse/_example tests/fixtures/crackme1 >/dev/null 2>&1 || true
```

Then, by hand, make `docs/reverse/_example/` contain:
- `index.md` — session header + Executive summary (crackme1 solved) + the binary link.
- `crackme1/00-target.md` — fixture, sha256, authorization "in-house CTF fixture (authorized)", goal.
- `crackme1/STATE.md` — `phase: report`, `status: done`, `next-step: (complete)`.
- `crackme1/01-triage-plan.md`, `02-static-plan.md`, `03-solve-plan.md` — per the `re-planning` template (with cost tags + numbered decision), telling the crackme1 story (`want[i] = argv[1][i] + 1`, then `strcmp`).
- `crackme1/findings.md` — cumulative facts + "solved".
- `crackme1/scripts/solve_crackme1.py` + `test_solve_crackme1.py` + `README.md` — the tested keygen (`keygen("AB") == "BC"`).
- `crackme1/artifacts/triage.txt` — real output: `sh skills/re-triage/triage.sh tests/fixtures/crackme1 docs/reverse/_example/crackme1 >/dev/null`.
- `crackme1/REPORT.md` — written from the new template: Executive summary first (solved; key = each username byte + 1), then the expert sections, Index.

- [ ] **Step 4: Verify the example's own script test passes**

```sh
( cd docs/reverse/_example/crackme1/scripts && python3 -m pytest test_solve_crackme1.py -q )
```
Expected: 1 passed.

- [ ] **Step 5: Update `ARCHITECTURE.md`**

- §4 skill tables: remove `re-preflight`; add `re-continue` to the spine; note the new capability skills land in Plans 3–4; state the family is **10 → 14**.
- §5: replace the `docs/reverse/<date>-slug/` layout with the `vibe-reverse-<dt>/<binary>/` + `index.md` + `STATE.md` layout (multi-binary).
- §7: rewrite from "preflight detects/installs" to "air-gapped — every tool is pre-baked; never install; degrade between baked tools."
- Add short subsections: long-running-op policy; checkpoint/resume.

- [ ] **Step 6: Update `AGENTS.md`**

- "What this repo is": skills count 10 → 14; the family removes preflight and adds `re-continue` (+ Plans 3–4 skills).
- Repo map: drop `re-preflight`; mention `new_session.sh`/`add_binary.sh`/`session_status.sh`.
- Conventions: add the air-gap no-install rule and the numbered-list rule.
- Replace the venv sentence in "On-the-fly Python" with "runs in the global `python3` (air-gapped image installs tools globally)."

- [ ] **Step 7: Update `README.md`** — status line to "v2 in progress: air-gapped refactor + advanced capabilities" and point at the v2 spec.

- [ ] **Step 8: Run the full deterministic suite**

```sh
for t in tests/scripts/test_*.sh; do sh "$t" || { echo "FAILED: $t"; exit 1; }; done
python3 -m pytest tests/scripts/ -q
( cd docs/reverse/_example/crackme1/scripts && python3 -m pytest -q )
```
Expected: all PASS (no reference to the deleted preflight/new_investigation tests).

- [ ] **Step 9: Commit**

```sh
git add -A
git commit -m "Plan2-1 T7: air-gapped orchestrator + routing tree; .gitignore sessions; regen example; docs"
```

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 1 slice):** air-gap framing §3.1 ✓ (T1, T7); remove preflight §4.1 ✓ (T1); new layout + multi-binary §3.2/§3.3 ✓ (T2, T7); long-running policy §3.4 ✓ (T1 ref, T4 kill-gate); numbered-list §3.5 ✓ (T4, T7); routing §3.6 ✓ (T7); re-planning §4.2 ✓ (T4); re-report §4.3 ✓ (T5); scripting/solve python §4.4 ✓ (T6); checkpoint/resume §6 ✓ (T2 STATE.md, T3 session_status + re-continue, T4 checkpoint duty). Example regen §9 ✓ (T7). Static/dynamic *hooks* §4.5 and the new capability skills are explicitly Plans 3–4.
- **Placeholders:** none — every script/test/template is complete; SKILL.md bodies use the repo's verbatim-frontmatter + "body MUST" contract + RED/GREEN scenario pattern.
- **Type/name consistency:** `new_session.sh` prints `vibe-reverse-<dt>` and the test asserts it; `add_binary.sh` prints `<session>/<basename>` and creates `STATE.md` with the `phase:`/`status:`/`next-step:`/`## Background jobs` fields that `session_status.sh` greps and `re-continue` reads; `report-template.md` section names match `test_report.sh`'s assertions; skill names equal directory names (`re-continue`).
