---
name: re-report
description: Use at the end of a reverse-engineering investigation — solved or not — to synthesize a final REPORT.md of what was tried, what worked, what failed, and ideas for next time. Symptoms you are about to violate it: "we failed, nothing to write", "skip the writeup". Keywords: report, writeup, summary, debrief, findings, conclusion, post-mortem.
---

# re-report

The terminal phase: synthesize `REPORT.md`.

## Core rule

Write the report at the end — **even on complete failure.** A documented dead end
seeds the next attempt. "We didn't solve it, so there's nothing to write" is
forbidden. *Violating the letter of this rule is violating its spirit.*

## Build it

```sh
sh make_report.sh <investigation-dir>
```

Scaffolds `REPORT.md` from the template and auto-indexes the plans, artifacts, and
scripts. Then **fill in the prose** by reading `00-target.md`, every
`NN-*-plan.md`, `findings.md`, and `artifacts/`:

- target & scope · outcome (solved / partial / failed)
- **approaches tried — what worked, what failed, and why**
- key findings (plain language) · dead ends & ideas · reproduction steps

## Review

Self-review the report (consistency / relevancy / evidence) per `re-planning`; as
the terminal deliverable, **escalate to the independent reviewer by default**
(`re-planning`'s `reviewer-prompt.md`). Relative paths only.
