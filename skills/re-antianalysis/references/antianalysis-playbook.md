# Anti-analysis playbook — detect, neutralize, re-verify

This phase finds the target's **own** defenses (anti-debug/anti-VM/anti-disasm/
self-integrity) and neutralizes them so analysis can proceed. It pairs with `re-dynamic`
(apply at detonation/emulation) and feeds `re-deobfuscate` (anti-disasm is a deob layer).

## Method

1. **Detect** — `antianalysis_scan.sh` + cross-check capa; map each hit with
   `anti-analysis-catalog.md` (sibling reference; technique → detection → bypass).
2. **Neutralize** per the catalog — patch the check out (keystone/lief), force the return
   in gdb, or make the emulator lie (qiling hooks faking TracerPid/CPUID/timing).
3. **Re-verify it proceeds** — confirm the target now runs past the check (sandboxed;
   running is a mandatory gate).
4. **Record** each neutralized check (evidence) for the report's "Obfuscation &
   anti-analysis" section.

## Failure modes / wrong-track signals

- **Empty/short dynamic trace = evasion, not inert** — the sample detected the
  sandbox/debugger and bailed; that's why you're here.
- **Stacked checks** — neutralizing one reveals a second; re-scan after each.
- **Self-integrity re-trigger** — patching the body trips a checksum; patch *after* the
  check, or hook the verifier to pass.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "Patched the check, moving on" | Re-verify the target actually proceeds before claiming the bypass works. |
| "I'll run it on the host to test the bypass" | Running is a mandatory gate — sandbox + consent (`re-dynamic`). |
| "Trace was empty, the sample does nothing" | Suspect evasion; that's the check you must neutralize. |

## Have I understood enough?

Done when the target **proceeds past its defenses** under analysis and each neutralized
check is recorded. Then route back to whatever the defense was blocking (deob/dynamic).

## Worked example

A Linux sample exits immediately under strace. `antianalysis_scan.sh` flags
`ptrace(PTRACE_TRACEME)`. Catalog → force the `ptrace` return in gdb (or patch the
branch). Re-run in the sandbox: it now reaches `main` and proceeds. Record **[confirmed]**
"ptrace self-attach anti-debug, neutralized by forcing the return" (evidence: trace
before/after).
