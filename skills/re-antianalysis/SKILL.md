---
name: re-antianalysis
description: Use when a reverse-engineering target resists analysis — anti-debugging (ptrace, IsDebuggerPresent), anti-VM/sandbox (CPUID, timing, VM artifacts), anti-disassembly, or self-integrity checks — to detect and neutralize those defenses. Keywords: anti-debug, anti-VM, anti-sandbox, anti-disassembly, ptrace, IsDebuggerPresent, rdtsc, cpuid, evasion, bypass checks, TracerPid, self-integrity.
---

# re-antianalysis

Detect & neutralize the target's **own** anti-analysis. Pairs with `re-dynamic`
(apply at detonation/emulation) and feeds `re-deobfuscate` (anti-disasm is a deob
layer).

## 1. Detect

```sh
sh antianalysis_scan.sh <target> <investigation-dir>
```

Flags string-based API checks + an `rdtsc`/`cpuid` instruction pass; cross-check
capa. Map each hit via `references/anti-analysis-catalog.md`.

## 2. Neutralize (pick per technique, cite the catalog)

- **Patch the check out** (keystone/lief via `re-scripting`).
- **Force the return** in gdb (e.g. set the ptrace/IsDebuggerPresent result).
- **Make the emulator lie** — qiling hooks faking `TracerPid`/CPUID/timing.

Re-verify the target now proceeds. Record each neutralized check for the report's
"Obfuscation & anti-analysis" section.

Slow/iterative work follows `../reverse-engineering/references/long-running-ops.md`.
End with **`re-planning`**. Relative paths only.
