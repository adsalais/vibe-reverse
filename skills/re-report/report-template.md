# REPORT — <binary> (<session>)

> Audience: an expert reverse engineer. Put the most important things first.
> Every claim traces to a finding in `findings.md` and carries its confidence tag
> (`[confirmed]`/`[likely]`/`[hypothesis]`); the verdict reflects the weakest link.

## Executive summary
- **Outcome / verdict:** solved / partial / failed — <one line; reflects the weakest cited finding>
- **What it is:** <one-line classification — e.g. ELF x86-64 downloader, VMProtect-packed>
- **Top findings (3–5):**
  1. **[confirmed]** <most important>
  2. **[likely]** ...
- **Headline IOCs:** <C2, mutex, key hashes — the few that matter most>

## Key findings
<the technical understanding, expert level; tag each claim and cite its finding/artifact>

## Approaches tried
For each phase: what was attempted, **what worked, what failed, and why**.

## Dead ends & ruled out
<FIRST-CLASS — do not bury. Drawn from the `## Dead ends` ledger in findings.md: what
was tried · why it failed (cite the artifact) · what it rules out / the next idea. In RE
a ruled-out path is signal.>

## Obfuscation & anti-analysis
<techniques encountered (packing, string/CFF/VM, anti-debug/anti-VM) and exactly how
each was defeated; cite artifacts/ and scripts/>

## Crypto & config
<algorithms identified (+ how), keys recovered, decrypted configuration>

## IOCs
<C2 URLs/IPs/domains, mutexes, file paths, registry keys, hashes — see config.json>

### YARA
```
<generated detection rule keyed on stable signatures>
```

## Reproduction
<exact steps / scripts to reproduce the result, if solved>

## Index
- Outputs: REPORT.md (this — source of truth) · REPORT.html (rendered deliverable)
- Plans: <list NN-*-plan.md>
- Artifacts: <list artifacts/...>
- Scripts: <list scripts/...>
