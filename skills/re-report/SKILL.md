---
name: re-report
description: Use at the end of a reverse-engineering investigation — solved or not — to synthesize a final REPORT.md of what was tried, what worked, what failed, and ideas for next time. Symptoms you are about to violate it: "we failed, nothing to write", "skip the writeup". Keywords: report, writeup, summary, debrief, findings, conclusion, post-mortem.
---

# re-report

The terminal phase: synthesize `REPORT.md`, **one per binary**, for an expert reader.

## Core rule

Write the report at the end — **even on complete failure.** A documented dead end
seeds the next attempt. "We didn't solve it, so there's nothing to write" is
forbidden. *Violating the letter of this rule is violating its spirit.*

## Write it directly

There is no scaffold script. **Write `REPORT.md` by hand** in markdown, copying the
structure of `report-template.md`, into the binary's folder. Fill every section by
reading `00-target.md`, every `NN-*-plan.md`, `findings.md`, and `artifacts/`.

- **Most-important-first:** lead with the **Executive summary** — verdict, the 3–5
  most important findings, and the headline IOCs. The reader is an **expert**, so
  the body is technical: key findings, approaches tried (what worked/failed/why),
  obfuscation & anti-analysis defeated, crypto & config recovered.
- **Traceable & honest:** every claim traces to a finding in `findings.md` and carries
  its confidence tag; the verdict reflects the weakest link (a conclusion built on a
  `[hypothesis]` is not presented as confirmed). Surface the **dead ends** prominently —
  what was ruled out is signal.
- **IOCs + a YARA rule** for the blue team; **Index** the `artifacts/`/`scripts/`
  yourself (list the folders).
- The session `index.md` also opens with a case-level **executive summary**
  synthesizing all binaries.

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

Self-review the report (consistency / relevancy / evidence) per `re-planning`; as
the terminal deliverable, **escalate to the independent reviewer by default**
(`../re-planning/reviewer-prompt.md`). Relative paths only.
