# Static analysis playbook — read the target, not the noise

Static analysis understands the target's logic **without running it**. The skill is
finding the few functions that matter in a sea of boilerplate, and knowing when one tool's
output is trustworthy.

## Method

1. Decompile/disassemble: `ghidra_decompile.sh <target> <inv>` (Ghidra → r2 → objdump).
2. **Find the target's code, skip the noise.** Start at `main` / the entry / a function of
   interest (a `strcmp`, a crypto call, the string you saw in triage). Ignore CRT startup,
   libc, and compiler boilerplate.
3. **Read the relevant function(s)** and state what they do in plain language.
4. Run the capability + string scan: `static_scan.sh <target> <inv>` (capa + FLOSS); read
   the capa tags (ATT&CK/MBC) and the recovered strings.
5. **Record findings with evidence** per
   `../../reverse-engineering/references/evidence-and-findings.md` — cite
   `artifacts/<file>:<line>` or an address. One decompiler's output is `[likely]`; make it
   `[confirmed]` only with an independent check (cross-tool, or dynamic later).
6. **Assess the route** (the SKILL's table): packed/obfuscated → `re-deobfuscate`;
   crypto/config → `re-crypto`/`re-config`; anti-analysis → `re-antianalysis`; a
   computed-value check → `re-solve`; needs running → `re-dynamic`.

## Delegate the heavy reads

Decompiled C and capa/FLOSS dumps are large; reading them in full pollutes your context.
Delegate the **mechanical extraction** per
`../reverse-engineering/references/delegating-to-subagents.md` — e.g. "extract the body of
`check()` from `artifacts/ghidra/decompiled.c` + the constants it uses, with line
numbers." You integrate the returned function into a finding. Delegate the *read*, never
the *judgment* of what it means or where to go next.

## Failure modes / wrong-track signals

- **Reading libc/CRT** as if it were the target — if every function looks generic, jump to
  `main` / the imports of interest.
- **Single-source trust** — the decompiler "said" something; that is `[likely]`. Decompiler
  output can be wrong (bad types, missed xrefs). Cross-check r2/objdump or verify dynamically.
- **Missed packing** — `.text` has high entropy / little recognizable code → it's packed;
  go to `re-deobfuscate`, don't decompile the stub forever.
- **Assuming constants** — "this is always 0x10" without checking callers/data.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "I'll read the whole decompilation myself" | It's huge. Delegate the mechanical read; integrate the result. |
| "The decompiler shows X, so X is confirmed" | One tool = `[likely]`. Cross-check or verify dynamically for `[confirmed]`. |
| "Let me just run it to see what it does" | That's `re-dynamic` (sandbox only). Static first. |
| "I'll trace every function to be safe" | Find the few that matter; the rest is noise. |

## Have I understood enough?

You are done when you can state the target's relevant logic well enough to **route or
solve**, and the key functions are findings with evidence. You do not need every function —
only the ones on the path to the goal.

## Worked example

`crackme1`: open `main`, skip `__libc_start_main` boilerplate. `main` reads
`argv[1]`/`argv[2]`, builds `want[i] = argv1[i] + 1`, then `strcmp(want, argv2)`. Record
**[likely]** (single decompiler) "check is a `+1` transform then `strcmp`", evidence
`artifacts/ghidra/decompiled.c:142`. It compares input to a *computed* value → route to
`re-solve` (direct inversion). The keygen run later makes it `[confirmed]`.
