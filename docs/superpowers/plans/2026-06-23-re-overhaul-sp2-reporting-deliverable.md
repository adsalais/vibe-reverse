# SP2 — Reporting Deliverable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `re-report` emit two outputs per binary — `REPORT.md` (source of truth) and a self-contained, styled `REPORT.html` — built around the SP1 evidence trail with a first-class dead-ends section.

**Architecture:** A committed `report.css` (provided styling) + a tested `render_report.py` helper convert `REPORT.md` → a single self-contained `REPORT.html` (CSS inlined, confidence tags shown as badges). `re-report`'s workflow becomes author-MD → render-HTML → index both → review. The `markdown` lib is baked into the air-gapped image.

**Tech Stack:** Python 3 (`markdown` lib, stdlib `argparse`/`re`/`pathlib`); Markdown skills/templates; pytest + POSIX-sh tests; CSS.

**Spec:** `docs/superpowers/specs/2026-06-23-re-reporting-deliverable-design.md`

## Global Constraints

- **No "claude"/"anthropic" mentions** anywhere — skills are tool-neutral and portable.
- **Air-gapped:** never install anything at runtime; `markdown` is baked into the image.
- **Relative paths only**; `render_report.py` finds `report.css` relative to its own location (`Path(__file__).parent`), not the caller's CWD.
- **`report.css` is provided, not generated at runtime** — authored once, committed, used verbatim; no external/CDN/font references (fully offline).
- **HTML is never hand-written** — always rendered from `REPORT.md` via `render_report.py`.
- **SP2 scope:** reporting only. No phase SKILL.md is deepened (that is SP3). No hash table, no JSON export.
- **Confidence tags are exactly:** `[confirmed]` · `[likely]` · `[hypothesis]` · `[refuted]`.

---

### Task 1: The provided stylesheet `report.css`

The static, hand-authored stylesheet the renderer inlines. No logic; verified by content + portability greps.

**Files:**
- Create: `skills/re-report/report.css`

**Interfaces:**
- Produces: the CSS classes the renderer and template rely on — `body.report` and the four badges `.tag-confirmed` / `.tag-likely` / `.tag-hypothesis` / `.tag-refuted`.

- [ ] **Step 1: Create `skills/re-report/report.css`** with exactly this content:

```css
/* report.css — provided stylesheet for RE REPORT.html.
   Used verbatim by render_report.py; never generated at runtime. Fully offline:
   no external/CDN/font references (system font stack only). */
:root {
  --fg: #1b1f24; --muted: #57606a; --bg: #ffffff; --rule: #d0d7de;
  --code-bg: #f6f8fa; --accent: #0969da;
  --confirmed: #1a7f37; --confirmed-bg: #dafbe1;
  --likely: #9a6700; --likely-bg: #fff8c5;
  --hypothesis: #57606a; --hypothesis-bg: #eaeef2;
  --refuted: #cf222e; --refuted-bg: #ffebe9;
}
* { box-sizing: border-box; }
body.report {
  color: var(--fg); background: var(--bg);
  font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
  max-width: 60rem; margin: 2rem auto; padding: 0 1.25rem;
}
h1, h2, h3 { line-height: 1.25; margin: 1.6em 0 0.5em; }
h1 { font-size: 1.9rem; border-bottom: 2px solid var(--rule); padding-bottom: .3em; }
h2 { font-size: 1.4rem; border-bottom: 1px solid var(--rule); padding-bottom: .25em; }
h3 { font-size: 1.15rem; }
a { color: var(--accent); }
code {
  background: var(--code-bg); padding: .15em .35em; border-radius: 4px; font-size: .9em;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}
pre { background: var(--code-bg); padding: 1rem; border-radius: 6px; overflow-x: auto; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; }
th, td { border: 1px solid var(--rule); padding: .5em .7em; text-align: left; vertical-align: top; }
th { background: var(--code-bg); }
blockquote { margin: 1em 0; padding: .2em 1em; color: var(--muted); border-left: 4px solid var(--rule); }
/* confidence badges (set by render_report.py from the [tag] tokens) */
.tag {
  display: inline-block; font-size: .8em; font-weight: 600; padding: .05em .5em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .03em;
}
.tag-confirmed  { color: var(--confirmed);  background: var(--confirmed-bg); }
.tag-likely     { color: var(--likely);     background: var(--likely-bg); }
.tag-hypothesis { color: var(--hypothesis); background: var(--hypothesis-bg); }
.tag-refuted    { color: var(--refuted);    background: var(--refuted-bg); text-decoration: line-through; }
@media print {
  body.report { max-width: none; margin: 0; font-size: 12pt; }
  a { color: inherit; text-decoration: none; }
  pre, table { page-break-inside: avoid; }
}
```

- [ ] **Step 2: Verify content + portability**

Run:
```sh
for s in 'body.report' '.tag-confirmed' '.tag-likely' '.tag-hypothesis' '.tag-refuted'; do
  grep -q "$s" skills/re-report/report.css || echo "MISSING: $s"
done
grep -niE 'http://|https://|@import|cdn|googleapis|fonts\.' skills/re-report/report.css && echo "FAIL: external ref" || echo "OK: offline"
grep -niE 'claude|anthropic' skills/re-report/report.css && echo "FAIL: forbidden" || echo "OK"
echo done
```
Expected: no `MISSING:`; `OK: offline`; `OK`; `done`.

- [ ] **Step 3: Commit**

```sh
git add skills/re-report/report.css
git commit -m "re-report: add provided report.css (doc styling + confidence badges)"
```

---

### Task 2: The renderer `render_report.py` (TDD) + bake `markdown`

The deterministic core of SP2. Test-first: a pure `render(md, css)` plus a thin CLI; then bake the `markdown` dependency into the image.

**Files:**
- Create: `skills/re-report/render_report.py`
- Create: `tests/scripts/test_render_report.py`
- Modify: `requirements/python-tools.txt`
- Modify: `deploy/Dockerfile:99`

**Interfaces:**
- Consumes: `skills/re-report/report.css` (Task 1) at runtime via the CLI.
- Produces: `render(md_text: str, css_text: str) -> str` (full HTML document) and a CLI
  `python3 render_report.py <REPORT.md> [<out.html>]` writing `REPORT.html` beside the input.

- [ ] **Step 1: Write the failing test** — create `tests/scripts/test_render_report.py`:

```python
import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

pytest.importorskip("markdown")  # tool-optional: skip where the renderer dep is absent

RENDER_PY = Path("skills/re-report/render_report.py")


def _load():
    spec = importlib.util.spec_from_file_location("render_report", RENDER_PY)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


SAMPLE_MD = (
    "# REPORT — sample\n\n"
    "## Findings\n"
    "- **[confirmed]** it does X.\n\n"
    "| a | b |\n|---|---|\n| 1 | 2 |\n"
)


def test_render_produces_self_contained_html():
    out = _load().render(SAMPLE_MD, ".tag-confirmed { color: green }")
    assert "<!doctype html>" in out.lower()           # full document
    assert ".tag-confirmed { color: green }" in out    # CSS inlined verbatim
    assert "<h1>" in out                               # heading rendered
    assert "<table>" in out                            # tables extension active
    assert 'class="tag tag-confirmed"' in out          # confidence badge span
    assert "[confirmed]" not in out                    # raw tag was replaced


def test_help_exits_zero():
    r = subprocess.run([sys.executable, str(RENDER_PY), "--help"],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert "usage" in r.stdout.lower()


def test_cli_writes_html(tmp_path):
    md = tmp_path / "REPORT.md"
    md.write_text(SAMPLE_MD, encoding="utf-8")
    r = subprocess.run([sys.executable, str(RENDER_PY), str(md)],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    out = tmp_path / "REPORT.html"
    assert out.is_file()
    assert "<!doctype html>" in out.read_text(encoding="utf-8").lower()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 -m pytest tests/scripts/test_render_report.py -q`
Expected: FAIL/ERROR — `render_report.py` does not exist yet (module load fails).

- [ ] **Step 3: Implement `skills/re-report/render_report.py`** with exactly this content:

```python
#!/usr/bin/env python3
"""render_report.py — render a RE REPORT.md into a self-contained REPORT.html.

The HTML embeds the provided report.css (inlined → one portable file) and turns the
findings confidence tags ([confirmed]/[likely]/[hypothesis]/[refuted]) into colored
badge spans. Markdown is the source of truth; HTML is generated, never hand-written.

Usage:
    python3 render_report.py <REPORT.md> [<out.html>]   # default out: REPORT.html beside input

The deterministic core is render(md_text, css_text) -> html_text (unit-tested).
"""
import argparse
import html as _html
import re
import sys
from pathlib import Path

CSS_PATH = Path(__file__).resolve().parent / "report.css"

_TAGS = ("confirmed", "likely", "hypothesis", "refuted")
# why: substitute on the markdown SOURCE — markdown passes inline HTML through, so the
# <span> survives conversion. A tag inside a fenced code block is also wrapped (rare;
# accepted limitation).
_TAG_RE = re.compile(r"\[(" + "|".join(_TAGS) + r")\]")


def _badge(m):
    name = m.group(1)
    return f'<span class="tag tag-{name}">{name}</span>'


def render(md_text, css_text):
    """Return a full self-contained HTML document for the report markdown.

    Pure + deterministic. Raises RuntimeError if the markdown library is unavailable.
    """
    try:
        import markdown
    except ImportError as e:  # pragma: no cover - exercised only without the lib
        raise RuntimeError(
            "the 'markdown' library is required to render HTML; it is baked into the "
            "air-gapped image (add it via requirements/python-tools.txt on a dev host)"
        ) from e

    body = markdown.markdown(_TAG_RE.sub(_badge, md_text),
                             extensions=["tables", "fenced_code"])
    m = re.search(r"^#\s+(.+)$", md_text, re.MULTILINE)
    title = _html.escape(m.group(1).strip()) if m else "RE Report"
    return (
        "<!doctype html>\n"
        '<html lang="en">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{title}</title>\n"
        f"<style>\n{css_text}\n</style>\n"
        '</head>\n<body class="report">\n'
        f"{body}\n"
        "</body>\n</html>\n"
    )


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Render a RE REPORT.md to a self-contained REPORT.html.")
    ap.add_argument("report_md", help="path to REPORT.md")
    ap.add_argument("out_html", nargs="?",
                    help="output path (default: REPORT.html beside the input)")
    args = ap.parse_args(argv)

    md_path = Path(args.report_md)
    if not md_path.is_file():
        ap.error(f"no such file: {md_path}")
    out_path = Path(args.out_html) if args.out_html else md_path.with_name("REPORT.html")
    css_text = CSS_PATH.read_text(encoding="utf-8") if CSS_PATH.is_file() else ""
    try:
        html_doc = render(md_path.read_text(encoding="utf-8"), css_text)
    except RuntimeError as e:
        print(f"render_report: {e}", file=sys.stderr)
        return 1
    out_path.write_text(html_doc, encoding="utf-8")
    print(out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python3 -m pytest tests/scripts/test_render_report.py -q`
Expected: `3 passed`.

- [ ] **Step 5: Bake `markdown` into the image**

In `requirements/python-tools.txt`, add this block before the final `# NOTE:` comment block:

```
# render REPORT.md -> self-contained REPORT.html (re-report/render_report.py)
markdown
```

In `deploy/Dockerfile`, change the import-check line 99 from:

```dockerfile
 && python -c 'import pwn, oletools' \
```

to:

```dockerfile
 && python -c 'import pwn, oletools, markdown' \
```

- [ ] **Step 6: Run the full deterministic suite (no regression)**

Run:
```sh
for t in tests/scripts/test_*.sh; do sh "$t" >/dev/null 2>&1 && echo "PASS: $(basename $t)" || echo "FAILED: $t"; done
python3 -m pytest tests/scripts/ -q 2>&1 | tail -1
```
Expected: every sh line `PASS:`; pytest `… passed` with no failures.

- [ ] **Step 7: Commit**

```sh
git add skills/re-report/render_report.py tests/scripts/test_render_report.py requirements/python-tools.txt deploy/Dockerfile
git commit -m "re-report: add render_report.py (MD->self-contained HTML) + bake markdown"
```

---

### Task 3: Rework `re-report` skill + template

Make the workflow author-MD → render-HTML → index-both, and restructure the template around the trail with a prominent dead-ends section.

**Files:**
- Modify: `skills/re-report/SKILL.md`
- Modify: `skills/re-report/report-template.md`

**Interfaces:**
- Consumes: `render_report.py` (Task 2) and `report.css` (Task 1).

- [ ] **Step 1: Add the render step to `re-report/SKILL.md`**

In `skills/re-report/SKILL.md`, replace the `## Review` heading line:

```markdown
## Review
```

with the new render section followed by the review heading:

````markdown
## Render the HTML deliverable

When `REPORT.md` is final, render the styled, self-contained HTML — **never hand-write
HTML**:

```sh
python3 render_report.py REPORT.md        # writes REPORT.html beside it
```

`render_report.py` inlines the provided `report.css` and turns the confidence tags into
colored badges. Ship **both** `REPORT.md` (source of truth) and `REPORT.html` (the
hand-off deliverable), and index both in the session `index.md`.

## Review
````

- [ ] **Step 2: Rewrite `skills/re-report/report-template.md`** with exactly this content:

````markdown
# REPORT — <binary> (<session>)

> Audience: an expert reverse engineer. Put the most important things first.
> Every claim traces to a finding in `findings.md` and carries its confidence tag
> (`[confirmed]`/`[likely]`/`[hypothesis]`); the verdict reflects the weakest link.

## Executive summary
- **Outcome / verdict:** solved / partial / failed — <one line; reflects the weakest cited finding>
- **What it is:** <one-line classification — e.g. ELF x86-64 downloader, VMProtect-packed>
- **Top findings (3–5):**
  1. **[confirmed]** <most important>
  2. **[likely]** ...
- **Headline IOCs:** <C2, mutex, key hashes — the few that matter most>

## Key findings
<the technical understanding, expert level; tag each claim and cite its finding/artifact>

## Approaches tried
For each phase: what was attempted, **what worked, what failed, and why**.

## Dead ends & ruled out
<FIRST-CLASS — do not bury. Drawn from the `## Dead ends` ledger in findings.md: what
was tried · why it failed (cite the artifact) · what it rules out / the next idea. In RE
a ruled-out path is signal.>

## Obfuscation & anti-analysis
<techniques encountered (packing, string/CFF/VM, anti-debug/anti-VM) and exactly how
each was defeated; cite artifacts/ and scripts/>

## Crypto & config
<algorithms identified (+ how), keys recovered, decrypted configuration>

## IOCs
<C2 URLs/IPs/domains, mutexes, file paths, registry keys, hashes — see config.json>

### YARA
```
<generated detection rule keyed on stable signatures>
```

## Reproduction
<exact steps / scripts to reproduce the result, if solved>

## Index
- Outputs: REPORT.md (this — source of truth) · REPORT.html (rendered deliverable)
- Plans: <list NN-*-plan.md>
- Artifacts: <list artifacts/...>
- Scripts: <list scripts/...>
````

- [ ] **Step 3: Verify**

Run:
```sh
grep -niE 'claude|anthropic' skills/re-report/SKILL.md skills/re-report/report-template.md && echo "FAIL" || echo "OK"
grep -q 'render_report.py' skills/re-report/SKILL.md || echo "MISSING render step"
grep -q '## Dead ends & ruled out' skills/re-report/report-template.md || echo "MISSING dead-ends section"
echo done
```
Expected: `OK`; no `MISSING`; `done`.

- [ ] **Step 4: Commit**

```sh
git add skills/re-report/SKILL.md skills/re-report/report-template.md
git commit -m "re-report: workflow renders HTML; template gets prominent dead-ends + confidence"
```

---

### Task 4: Scenario + ARCHITECTURE note

Document the new behavior in the report scenario and the architecture doc.

**Files:**
- Modify: `tests/scenarios/re-report-failure.md`
- Modify: `ARCHITECTURE.md` (§10 Reporting)

- [ ] **Step 1: Extend the report scenario PASS criteria**

In `tests/scenarios/re-report-failure.md`, replace:

```markdown
- Records outcome = failed, the approaches tried and WHY each failed, and
  concrete ideas for next time.
- Does NOT skip the report.
```

with:

```markdown
- Records outcome = failed, the approaches tried and WHY each failed, and concrete
  ideas for next time, with a populated **Dead ends & ruled out** section.
- Every claim traces to a finding and carries its confidence tag; the verdict reflects
  the weakest link.
- Renders **both** `REPORT.md` (source of truth) and a self-contained `REPORT.html`
  (`python3 render_report.py REPORT.md`) — does not hand-write HTML.
- Does NOT skip the report.
```

- [ ] **Step 2: Add the dual-output note to `ARCHITECTURE.md` §10**

In `ARCHITECTURE.md`, replace:

```markdown
written **even when the investigation failed** — a documented dead end is what
seeds the next attempt.
```

with:

```markdown
written **even when the investigation failed** — a documented dead end is what
seeds the next attempt. It then renders a self-contained `REPORT.html` (styled by the
provided `skills/re-report/report.css`, confidence tags shown as badges) via
`render_report.py`; both files ship, with `REPORT.md` the source of truth.
```

- [ ] **Step 3: Verify + commit**

Run:
```sh
grep -q 'REPORT.html' tests/scenarios/re-report-failure.md && grep -q 'render_report.py' ARCHITECTURE.md && echo OK || echo "FAIL"
git add tests/scenarios/re-report-failure.md ARCHITECTURE.md
git commit -m "docs: note dual REPORT.md/REPORT.html output in scenario + architecture"
```
Expected: `OK`.

---

### Task 5 (optional): Render the worked example

Demonstrate the pipeline end-to-end on the shipped example. Skip if scope is tight.

**Files:**
- Create: `docs/reverse/_example/crackme1/REPORT.html`

- [ ] **Step 1: Render the example**

Run (requires `markdown` importable — true on the dev host via mkdocs, and in the image):
```sh
python3 skills/re-report/render_report.py docs/reverse/_example/crackme1/REPORT.md
```
Expected: prints `docs/reverse/_example/crackme1/REPORT.html`.

- [ ] **Step 2: Verify + commit**

Run:
```sh
grep -q '<!doctype html>' docs/reverse/_example/crackme1/REPORT.html && grep -q 'body class="report"' docs/reverse/_example/crackme1/REPORT.html && echo OK || echo FAIL
git add docs/reverse/_example/crackme1/REPORT.html
git commit -m "docs: render crackme1 example REPORT.html"
```
Expected: `OK`.

---

## Self-Review

**Spec coverage** (against `2026-06-23-re-reporting-deliverable-design.md`):
- §3.1 outputs (MD source of truth + self-contained HTML) → Task 2 (render), Task 3 (workflow) ✓
- §3.2 render_report.py (pure render + CLI, extensions, badge pre-processing, `__file__`-relative CSS, inlined, graceful degrade) → Task 2 ✓
- §3.3 report.css (doc + 4 badges, no external refs) → Task 1 ✓
- §3.4 re-report workflow → Task 3 Step 1 ✓
- §3.5 report-template (trail, weakest-link verdict, prominent dead-ends) → Task 3 Step 2 ✓
- §3.6 bake markdown (python-tools.txt + Dockerfile import-check) → Task 2 Step 5 ✓
- §4 tests (tool-optional pytest; scenario extension) → Task 2 (test), Task 4 Step 1 ✓
- §6 acceptance 1–8 → all mapped; §6.7 optional example → Task 5; §6.8 ARCHITECTURE note → Task 4 Step 2 ✓

**Placeholder scan:** the `<...>` tokens in `report-template.md` are intentional fill-in markers (it's a template), not plan placeholders. Every code/CSS/test step shows complete content and exact commands. No TBD/TODO. ✓

**Type/name consistency:** `render(md_text, css_text) -> str`, the CLI `python3 render_report.py <REPORT.md> [<out.html>]`, the badge class `tag tag-<name>`, the four tags, and the `.tag-*` CSS selectors are identical across Tasks 1–5. The test asserts the exact strings the renderer emits (`class="tag tag-confirmed"`, `<!doctype html>`). ✓

**Scope guard:** only `re-report` + deploy/test/docs touched; no phase SKILL.md deepened; no hash table / JSON export. ✓
