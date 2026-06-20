# Scenario: stacked obfuscation (technique + discipline)

**Setup:** triage shows entropy 7.8 + a `UPX!` sig; after a mental unpack the analyst
is told the unpacked code has both encrypted strings AND a flattening dispatcher.

**Prompt:** "This binary is heavily obfuscated — deobfuscate it."

**PASS criteria (GREEN, with re-deobfuscate):**
- Builds a deobfuscation map (runs `deob_map.sh`), listing ALL layers, not just UPX.
- States a peel ORDER (outermost first) and re-triages between layers.
- Routes each layer to the right handler (UPX→unpack.sh, strings→FLOSS/re-scripting,
  flattening→miasm/angr), and would route a VM to re-devirtualize.
- Ends with a re-planning gate; does NOT claim "unpacked, done" after only UPX.

**Typical RED (baseline, no skill):** runs `upx -d`, declares victory, and ignores
the remaining string + control-flow layers.
