# REPORT — <binary> (<session>)

> Audience: an expert reverse engineer. Put the most important things first.

## Executive summary
- **Outcome / verdict:** solved / partial / failed — <one line>
- **What it is:** <one-line classification — e.g. ELF x86-64 downloader, VMProtect-packed>
- **Top findings (3–5):**
  1. <most important>
  2. ...
- **Headline IOCs:** <C2, mutex, key hashes — the few that matter most>

## Key findings
<the technical understanding, expert level: behaviour, structure, notable routines>

## Approaches tried
For each phase: what was attempted, **what worked, what failed, and why**
(hypotheses where unproven).

## Obfuscation & anti-analysis
<techniques encountered (packing, string/CFF/VM, anti-debug/anti-VM) and exactly
how each was defeated; cite artifacts/ and scripts/>

## Crypto & config
<algorithms identified (+ how), keys recovered, decrypted configuration>

## IOCs
<C2 URLs/IPs/domains, mutexes, file paths, registry keys, hashes — see config.json>

### YARA
```
<generated detection rule keyed on stable signatures>
```

## Dead ends & ideas for next time
<emphasize on failure — these seed the next attempt>

## Reproduction
<exact steps / scripts to reproduce the result, if solved>

## Index
- Plans: <list NN-*-plan.md>
- Artifacts: <list artifacts/...>
- Scripts: <list scripts/...>
