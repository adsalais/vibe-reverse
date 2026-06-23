# RE harness overhaul — SP2: Reporting deliverable

> **Status:** design approved (brainstorming), ready for implementation plan.
> **Scope of this spec:** sub-project **SP2** of the RE-skills overhaul.
> **Depends on:** SP1 (evidence & honesty spine) — merged to `main`.
> **Audience:** an engineer/agent implementing the change to the `skills/` tree.

## 1. Why

SP1 gave the investigation a defensible, honest evidence trail (`findings.md` with
confidence tags + mandatory evidence, enforced at the `re-planning` gate). SP2 makes
the **terminal deliverable** live up to it: the final report must *enforce* the trail
(every claim traces to a finding and carries its confidence), surface what was ruled
out, and ship in a form a blue-teamer can actually hand off — a polished, self-contained
HTML document alongside the Markdown source.

Today `re-report` writes a single hand-authored `REPORT.md`. SP1 added a one-line
"traceable & honest" rule; SP2 builds the report *around* that rule and adds a styled
HTML rendering.

## 2. Scope

**In:**
- Rework `re-report` + `report-template.md` so the report is structured around the SP1
  evidence trail (every claim → a finding + its confidence tag; the verdict reflects the
  weakest link) with a **first-class dead-ends section**.
- Produce **two outputs** per binary: `REPORT.md` (source of truth) and `REPORT.html`
  (a self-contained, styled deliverable).
- A committed, hand-authored `report.css` (the "provided" stylesheet) and a
  `render_report.py` helper that converts MD → HTML.
- Bake the `markdown` library into the air-gapped image.

**Out (YAGNI — explicitly deferred/dropped):**
- Integrity/hash table and formal chain-of-custody (SP1 set the audit bar lighter than
  forensic; the binary sha256 already lives in `00-target.md`).
- Structured/machine-readable JSON export (`config.json` from `re-config` already covers
  IOC tooling needs).

## 3. Design

### 3.1 Outputs
- **`REPORT.md` is the source of truth.** `re-report` authors it by hand from the
  template, preserving the SP1 trace-to-findings contract. **HTML is never hand-written.**
- **`REPORT.html` is a single self-contained file** — the CSS is **inlined** in a
  `<style>` block (not linked) so the deliverable is one portable file (email/archive),
  with no external asset to lose.

### 3.2 Rendering pipeline — `skills/re-report/render_report.py`
A small, tested helper shipped in the skill.

- **CLI:** `python3 render_report.py <REPORT.md> [<out.html>]` — `out.html` defaults to
  `REPORT.html` beside the input. Non-interactive, `--help`-able.
- **Pure core (testable):** `render(md_text: str, css_text: str) -> str` returns the full
  HTML document. The CLI layer does file IO only. (Per `re-scripting`: unit-test the
  deterministic core with known input/output.)
- **Conversion:** `markdown.markdown(body, extensions=['tables', 'fenced_code'])`.
- **Confidence badges:** before conversion, wrap the four exact tokens
  `[confirmed]` / `[likely]` / `[hypothesis]` / `[refuted]` as
  `<span class="tag tag-<name>"><name></span>` so the HTML shows colored confidence
  badges (the CSS owns the colors). *Known minor limitation:* a tag appearing inside a
  fenced code block would also be wrapped — acceptable and rare; documented in the script.
- **Shell + CSS:** wrap the rendered body in a minimal HTML5 document
  (`<!doctype html>` … `<meta charset="utf-8">` … `<title>` from the MD's first `#`
  heading … `<style>{css}</style>` … `<body class="report">{body}</body>`). The CSS is
  read from `report.css` located **relative to the script** (`Path(__file__).parent /
  "report.css"`), so it works regardless of the caller's working directory.
- **Graceful degrade:** if `import markdown` fails (e.g. a dev host without it), print a
  clear message to stderr ("markdown not installed; it is baked into the air-gapped
  image") and exit non-zero — never emit a half-rendered file.

### 3.3 `skills/re-report/report.css` (the provided stylesheet)
Hand-authored once and committed; used verbatim every run (never generated at runtime).
Responsibilities:
- Clean, readable, **print-friendly** document styling (sensible typography, max-width,
  table borders, code-block background, heading hierarchy).
- The four confidence badges: `.tag-confirmed`, `.tag-likely`, `.tag-hypothesis`,
  `.tag-refuted` — visually distinct (e.g. green / amber / grey / struck-through), so
  confidence reads at a glance.
- Tool-neutral, no external font/CDN references (air-gapped — fully offline).

### 3.4 `skills/re-report/SKILL.md` workflow
Revised order:
1. **Author `REPORT.md`** from the template — every claim traces to a finding and
   carries its confidence tag; the executive-summary verdict reflects the **weakest
   link**; the dead-ends section is filled.
2. **Render:** `python3 render_report.py REPORT.md` → `REPORT.html` (styled by the
   provided `report.css`). Never hand-write HTML.
3. **Index both** `REPORT.md` and `REPORT.html` in the session `index.md`.
4. **Review:** self-review + independent reviewer by default (unchanged from SP1).

### 3.5 `skills/re-report/report-template.md`
- Keep executive-summary-first; the verdict line states the weakest cited finding.
- Every key-finding / IOC line carries its confidence tag (`[confirmed]` etc.).
- Elevate **"Dead ends & ruled out"** to a prominent, first-class section tied to the
  `## Dead ends` entries in `findings.md` (what was tried · why it failed · what it rules
  out) — honesty is a headline, not a footnote.

### 3.6 Deploy — bake `markdown`
- Add `markdown` to `requirements/python-tools.txt` (pure-Python, no system deps).
- Add `markdown` to the `deploy/Dockerfile` import-check gate (the `python -c 'import …'`
  line that fails the build on a broken install).
- One image rebuild on the Docker host (`sh deploy/build.sh` + `smoke.sh`). The host
  `requirements/setup.sh` path installs from the same `python-tools.txt`, so no separate
  change there.

## 4. Tests (pragmatic)
- **Deterministic (pytest):** `tests/scripts/test_render_report.py`, following the
  existing pattern for importing a skill-dir script. Calls `render(md, css)` on a small
  sample containing a heading, a table, and a `[confirmed]` tag; asserts the output is a
  full HTML doc containing the inlined CSS, an `<h1>`, a `<table>`, and a
  `class="tag tag-confirmed"` span. **Tool-optional:** `skip` if `import markdown` fails.
- **Scenario (light):** extend `tests/scenarios/re-report-failure.md` PASS criteria to
  require **both** `REPORT.md` and `REPORT.html`, claims traced to findings with
  confidence, and a populated dead-ends section. No new scenario file.
- The full deterministic suite (sh + pytest) still exits 0.

## 5. Out of scope (deferred)
- Integrity/hash table, chain-of-custody → dropped (audit bar is lighter than forensic).
- Structured JSON export → dropped (config.json covers it).
- Phase-skill depth + subagent delegation mechanics → **SP3**.

## 6. Acceptance criteria
1. `render_report.py` exists with a pure `render(md_text, css_text)` core + a CLI; reads
   `report.css` relative to its own location; inlines the CSS; converts tables + fenced
   code; wraps the four confidence tags as badge spans; degrades clearly if `markdown` is
   absent.
2. `report.css` exists, is committed, styles the document + the four `.tag-*` badges, and
   references no external/CDN assets.
3. `re-report/SKILL.md` directs: author `REPORT.md` → render `REPORT.html` → index both →
   review; HTML is never hand-written.
4. `report-template.md` ties claims to findings + confidence, states a weakest-link
   verdict, and has a prominent dead-ends section.
5. `markdown` is in `python-tools.txt` and the `deploy/Dockerfile` import-check.
6. `test_render_report.py` passes where `markdown` is importable and skips otherwise; the
   full suite exits 0.
7. *(Optional)* `docs/reverse/_example/crackme1/REPORT.html` is rendered from its
   `REPORT.md` to demonstrate the pipeline.
8. No "claude"/"anthropic" mentions; relative paths only; no phase SKILL.md deepened
   (that is SP3); a light `ARCHITECTURE.md` §10 note records the dual output.

## 7. Open questions
None — resolved during brainstorming: render via the **baked `markdown` lib** + a helper
(rebuild accepted); **I author one committed `report.css`** (used verbatim); SP2 scope is
**report rework + dual HTML/MD + prominent dead-ends only**; the HTML is **a single file
with CSS inlined**.
