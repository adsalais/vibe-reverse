# Evidence & findings — the audit contract

Every reverse-engineering investigation must leave a trail another analyst can
re-walk. This reference defines how findings are recorded, how confident we are in
them, what "verified" means, and what may be delegated to a subagent. It is cited by
the orchestrator, `re-planning` (which enforces it at the gate), the phase skills, and
`re-report`.

## The finding (atomic audit unit)

A **finding** is one claim we believe, recorded in the binary's `findings.md`. Every
finding carries:

- a **confidence tag** — `[confirmed]` / `[likely]` / `[hypothesis]` / `[refuted]`;
- the **claim**, in plain language;
- an **`evidence:` pointer** — **mandatory**;
- a **`verified:` note** — required when `[confirmed]` (the independent check);
- an **optional id** `[F-NNN]` — add only when the finding is cited elsewhere.

**The binding rule: an entry with no evidence pointer is not a finding — it is a
hypothesis.** Evidence is one of:

- `artifacts/<file>:<line>` (e.g. a line in decompiled output),
- an address `0x…` inside a named artifact,
- `scripts/<file>` plus a named test vector.

### `findings.md` layout

Two sections per binary — a light per-entry list, no table:

```markdown
# Findings — <binary>

## Findings
- **[confirmed]** main compares argv[2] to a +1 transform of argv[1].
  evidence: `artifacts/ghidra/decomp.c:142` · verified: re-ran `./cm AB BC` → "Correct!"
- **[likely]** strings decrypted with single-byte XOR 0x5a.
  evidence: `artifacts/floss.txt:30`

## Dead ends
- tried run-to-unpack via qiling — failed: emulator detected via rdtsc timing
  (`artifacts/dynamic/qiling.log:88`). Rules out naive emulation; next: patch the hook.
```

`findings.md` is the **source of truth**. Plans, `STATE.md`, and `REPORT.md` reference
findings (by id when one is assigned, else by claim) rather than restating them. It is
greppable: `grep '\[confirmed\]' findings.md`.

## Confidence — one 4-value tag

| tag | meaning |
|---|---|
| `[confirmed]` | independently verified (see below); the entry states *how*. |
| `[likely]` | strong single-source evidence, not independently verified. |
| `[hypothesis]` | plausible, unverified — may be wrong. |
| `[refuted]` | disproved; kept on the record, never deleted. |

**Propagation:** a conclusion is only as strong as its weakest cited finding. A
conclusion resting on a `[hypothesis]` cannot itself be `[confirmed]`. The report's
verdict reflects the weakest link.

## Verification — what makes a finding `[confirmed]`

"I read it once in the decompiler" is `[likely]` at best. A finding is `[confirmed]`
only after an **independent** check agrees. In RE that means one of:

- **Re-run the real binary** with the recovered input/transform and confirm the
  expected behaviour (sandboxed for untrusted targets — see `re-dynamic`).
- **Cross-tool agreement** — Ghidra vs radare2 vs objdump; disagreement → not confirmed.
- **Reproduce a transform/decrypt with a known vector** — e.g. a `MZ` / `\x7fELF`
  header appearing in decrypted output, or a published cipher test vector.
- **Emulation / dynamic result matches the static prediction.**
- **Solver output accepted by the binary** (the recovered key/input is taken).

Load-bearing claims — anything that headlines the report or drives the next phase —
must be `[confirmed]` before being presented as fact.

## Honesty — dead ends are first-class

A ruled-out approach is real signal in RE. Record every failed attempt in `## Dead
ends`: *what was tried · why it failed (with an evidence pointer) · what it rules out /
the next idea.* When a finding is disproved, re-tag it `[refuted]` and add a dead-end
line. **Nothing tried is ever silently deleted.**

## Delegation boundary — what a subagent may do

Subagents are for **mechanical, bounded, single-purpose** work only: read-and-extract
from a large artifact, run a scan and summarise, apply a deterministic transform, run a
tested script.

A mechanical subagent **returns raw results + evidence pointers** and **does not write
`findings.md`** — the piloting agent integrates the result into a finding with a
confidence tag. Delegated work still carries the cost-tag + soft budget +
**ask-before-kill** rule (`long-running-ops.md`).

**Judgment, iteration, and strategy stay in the piloted main loop, under the gate.**
Open-ended work — *"figure out how to deobfuscate this"*, *"decide what to try next"*,
anything that tries many approaches — is **never** handed to a subagent that could
churn invisibly. The human must see open-ended work happen; the approval gate bounds it.
