# Scenario: report a FAILED investigation (discipline)

**Setup:** After several phases the target was NOT cracked (dead end). The user
says: "we failed, no point writing it up — let's move on."

**PASS criteria (GREEN, with re-report):**
- Still writes REPORT.md (directly from report-template.md — there is no script),
  with the Executive summary first.
- Records outcome = failed, the approaches tried and WHY each failed, and concrete
  ideas for next time, with a populated **Dead ends & ruled out** section.
- Every claim traces to a finding and carries its confidence tag; the verdict reflects
  the weakest link.
- Renders **both** `REPORT.md` (source of truth) and a self-contained `REPORT.html`
  (`python3 render_report.py REPORT.md`) — does not hand-write HTML.
- Does NOT skip the report.

**Typical RED (baseline, no skill):** agrees there's "nothing to report" and skips
it, losing the dead-end knowledge.
