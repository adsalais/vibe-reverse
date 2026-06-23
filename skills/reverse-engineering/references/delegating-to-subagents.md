# Delegating to subagents — mechanical work only

Subagents preserve the piloting agent's context by doing **bounded, mechanical** work and
returning a tight result. The boundary is set by `evidence-and-findings.md` (the SP1
contract): mechanical-only, return results + evidence pointers, **never write findings**,
and judgment / iteration / strategy stay in the piloted loop under the gate. This
reference is the *how*.

## When to delegate

Delegate when the work is mechanical, bounded, and single-purpose:
- **Read a large/verbose artifact to extract a specific thing** — a function out of
  decompiled C, the relevant calls out of a long strace, the hits out of a capa/FLOSS dump.
- **Apply a deterministic transform** — decode/transform a blob with a *known* routine.
- **Run a tested script** and return its output.

Do NOT delegate judgment: deciding the approach, "figure out how to deobfuscate this",
choosing the next phase, or anything that needs trying several things. That stays with
you, in view of the human, bounded by the gate.

## The dispatch contract

A good mechanical dispatch is:
- **Focused** — one artifact, one question. Not "analyze this binary".
- **Self-contained** — give the subagent the artifact path and exactly what to extract.
  Do NOT paste the investigation history; it does not need (or get) your context.
- **Specific about output** — it returns the extracted content **plus an evidence
  pointer** (`artifacts/<file>:<line>` or a `0x…` address), and nothing else.
- **Bounded** — it must not write `findings.md`, edit files, or decide next steps.

### Template

```
Delegate (mechanical, read-only):
- Artifact: artifacts/<file>
- Extract: <exactly what — e.g. "the full body of function check_license and any
  constants/strings it references">
- Return: the extracted content + an evidence pointer (artifacts/<file>:<line> or 0x…).
  Do NOT interpret intent, do NOT write findings, do NOT decide next steps.
```

## Budget

Delegated work is still slow work: state the cost (⚡/⏳/🐢), run it under the soft budget,
and **ask before killing** — see `long-running-ops.md`. A mechanical read is usually ⚡/⏳.
**If you find yourself wanting the subagent to "try a few things" to get the answer, that
is the signal NOT to delegate** — the task is judgment; keep it piloted.

## Integrate

When the subagent returns, *you* turn its raw result into one or more findings with a
confidence tag and the evidence pointer it gave you (per `evidence-and-findings.md`). The
subagent surfaced the bytes; you decide what they mean.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "Send a subagent to crack/solve/deobfuscate this" | That's judgment + iteration. Pilot it yourself under the gate. |
| "Let it figure out the approach and report back" | Open-ended = invisible churn. Delegate a *read*, not a decision. |
| "Paste the whole investigation so it has context" | It needs only the artifact + the extraction ask. History pollutes it. |
| "It can update findings.md while it's in there" | Subagents never write findings — you integrate the result. |
