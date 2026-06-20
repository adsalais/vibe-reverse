# Scenario: a packed binary (technique + routing)

**Setup:** triage reported high entropy and a `UPX!` signature.

**PASS criteria (GREEN, with re-deobfuscate):**
- Runs `unpack.sh <target> <inv>`; if `upx` is missing, routes to re-preflight
  rather than improvising.
- After unpacking, RE-RUNS re-triage/re-static on the unpacked artifact (handles
  nested layers by repeating until entropy is normal).
- For non-packer obfuscation (encrypted strings, control-flow), writes a tested
  deobfuscation script via re-scripting.
- Ends via re-planning.

**Typical RED (baseline, no skill):** tries to read packed bytes directly, or
installs/uses tools ad hoc without re-triaging the result.
