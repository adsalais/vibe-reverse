---
name: re-continue
description: Use when resuming a paused reverse-engineering investigation in a new session or on another day — reads the vibe-reverse session state, collects any finished background results, and briefs you on where things stand before continuing. Keywords: continue, resume, pick up investigation, what's the status, reopen session, carry on.
---

# re-continue

Rehydrate a paused investigation **from disk** — assume no memory of prior chat.

## 1. Locate the session (read-only)

```sh
sh session_status.sh [session-dir]
```

Default: the newest `vibe-reverse-*/` in the current directory; pass a path to pick
another. It prints, per binary: phase, status, latest plan, next step, and how many
background jobs are still marked `running`. It never changes anything.

## 2. Collect finished background results

For each `running` row in a binary's `STATE.md` **Background jobs** ledger, check the
expected artifact. If it is now present, read/summarise it and mark that row `done`
(a finished detonation/decompile from last session may be waiting).

## 3. Brief the user

Summarise where things stand: current binary, phase, last approved plan, the pending
next step, open questions, and anything newly collected in step 2. Keep it short —
point into the files rather than dumping them.

## 4. Present the decision and STOP

Offer the pending decision as a **numbered list** ending "Which option?", then hand
back to the orchestrator loop / the `re-planning` gate. **Do not auto-run the next
phase** — the human pilots.

The live cursor is each binary's `STATE.md`, written by **`re-planning`** at every
gate. Relative paths only.
