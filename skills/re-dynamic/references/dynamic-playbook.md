# Dynamic analysis playbook — run it safely, read the trace

Dynamic analysis observes the target **running** — but only inside a sandbox (see the
SKILL's core rule; never on the host). The skill is choosing the lightest technique that
answers your question, and reading the trace for the few events that matter.

## Method

1. **Confirm the sandbox** (microVM / `--network none` container / throwaway VM) and
   consent — per the SKILL's core rule. Record the sandbox in `00-target.md`.
2. **Pick the technique:** **trace** (`strace`/`ltrace`) for syscalls/library calls
   (files, network, the comparison); **gdb** to breakpoint, read a runtime value, or force
   a branch; **emulate** (qiling) to self-decrypt strings / drop config / run-to-unpack
   without full detonation.
3. **Run it** with the right arguments/input (the check often needs `argv`/stdin).
4. **Read the trace** for the events you care about: the `strcmp`/`memcmp` of your input,
   the `open`/`connect`/`write`, the dropped file. Capture the runtime values.
5. **Record findings with evidence** per
   `../../reverse-engineering/references/evidence-and-findings.md` — cite the trace
   artifact + line. Re-running the real binary and seeing the expected behaviour is a
   strong `[confirmed]` check.

## Delegate the heavy reads

A full strace/ltrace can be thousands of lines. Delegate the **mechanical extraction** per
`../reverse-engineering/references/delegating-to-subagents.md` — e.g. "from
`artifacts/dynamic/strace.log`, return every `openat`/`connect` line + line numbers."
Never delegate the *decision to run* or the *strategy* — running is judgment and is
dangerous; it stays piloted.

## Failure modes / wrong-track signals

- **Empty / very short trace** usually means the sample **detected the sandbox** and bailed
  (anti-debug/anti-VM/timing) — not "it does nothing". Route to `re-antianalysis`.
- **Wrong input** — the interesting path needs the right `argv`/stdin/file; a bare run exits
  early.
- **Emulation mismatch** — qiling rootfs/hooks wrong → behaviour diverges from the real
  binary. Treat emulator-only artifacts with suspicion until cross-checked.
- **Mistaking sandbox noise** (loader, environment) for the target's behaviour.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "Just run it on the host quickly" | Untrusted code on the host = compromise. Sandbox only. |
| "The trace is empty, so it does nothing" | Suspect sandbox detection → `re-antianalysis`. |
| "Let a subagent run it and figure it out" | Running is judgment + dangerous. Pilot it yourself. |
| "Emulation worked, so the real binary does too" | Emulation can diverge. Cross-check before `[confirmed]`. |

## Have I understood enough?

You are done when you have **observed the behaviour you came for** (the comparison, the
dropped file, the C2 callback) with a trace artifact as evidence — or you have **confirmed
evasion** and should route to `re-antianalysis`. You need the answer to the question that
sent you here, not a full behavioural map.

## Worked example

A crackme that compares input at runtime: detonate in the microVM
(`vmrun.sh <sample> <inv> --mode trace`), then read `artifacts/dynamic/strace.log` for the
`read`/`write` around the comparison. It reads `argv[2]` and compares to a fixed string →
record **[confirmed]** "accepts key == <value>", evidence `artifacts/dynamic/strace.log:NN`.
