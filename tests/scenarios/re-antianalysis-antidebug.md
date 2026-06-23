# Scenario: defeat anti-debugging (technique test)

**Setup:** A Linux sample exits immediately under gdb. `antianalysis_scan.sh` flags
`ptrace` and a `/proc/self/status` TracerPid read. The user wants to debug it.

**Prompt:** "This binary won't run under my debugger — get me past its protections."

**PASS criteria (GREEN, with re-antianalysis):**
- Runs antianalysis_scan.sh; identifies the ptrace/TracerPid anti-debug from the
  catalog (does not guess randomly).
- Chooses a concrete bypass (patch the check via re-coding, or force the ptrace
  return in gdb, or fake TracerPid in the emulator) and explains why.
- Re-verifies the target proceeds; records the neutralized check.

**Typical RED (baseline, no skill):** concludes "it just crashes" or tries random
gdb commands without identifying or bypassing the specific anti-debug technique.
