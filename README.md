# Reverse-Engineering Harness

A portable family of [skills](https://agentskills.io) that turns an AI agent into a
**disciplined reverse-engineering co-pilot** — you steer; it does the heavy lifting and
leaves an auditable trail.

It **triages the target once** to get its bearings, then runs the investigation as a
**hypothesis loop**, not a black box — at each phase:

> rank the live hypotheses → test the most probable → record what failed → re-assess → … → report

The agent **proceeds on its own for confident, reversible steps** and **stops for your
approval** when a step is uncertain or irreversible — running an untrusted target,
dropping a new binary, destructive patching, anything long-running. You keep control of
direction without rubber-stamping every move.

Works identically in **Claude Code** and **opencode** (one install). Heavy tool output
goes to files; you read short, self-checked summaries.

## Why you can trust the output

- **Evidence ledger.** Every finding in `findings.md` carries a confidence tag —
  `[confirmed]` / `[likely]` / `[hypothesis]` / `[refuted]` — and a **mandatory evidence
  pointer** (an artifact + line/address). No evidence, no finding.
- **Verification before "confirmed".** A claim is `[confirmed]` only once an independent
  check agrees — re-running the binary, cross-tool agreement, a known-plaintext vector.
- **Honesty.** Dead ends are first-class — what was tried, why it failed, what it rules
  out — because in RE a ruled-out path is real signal.
- **Self-correcting gate.** Each plan is self-reviewed (and, when uncertain, checked by an
  independent reviewer subagent) for missing evidence, overclaims, and contradictions.

## What's inside

**Spine** (every investigation): `reverse-engineering` (orchestrator) · `re-planning`
(the hypothesis loop + doubt-gate + resumable checkpoint) · `re-coding` (tested code —
Python, shell, or self-contained **Rust** — written via a plan → implementer → review
loop) · `re-continue` (resume a paused case from disk).

**Phases** — each with a depth playbook (method, failure modes, "have I understood
enough?", a worked example):

`re-triage` → `re-static` → `re-deobfuscate` (owns the peel loop; dispatches
`re-devirtualize`) · `re-antianalysis` · `re-crypto` · `re-config` · `re-solve` ·
`re-dynamic` (run / trace / emulate — **sandbox only**) → `re-report`.

Each session lives in a `vibe-reverse-<datetime>/` folder in your working directory:
per-binary `findings.md`, a resumable `STATE.md`, numbered phase plans, `artifacts/`,
`scripts/`, and a final **`REPORT.md` + self-contained `REPORT.html`** (one per binary)
with IOCs and a YARA rule for the blue team.

## Quickstart

1. Install the skills — see `INSTALL.md`.
2. In your agent: *"Reverse-engineer ./challenge."* The `reverse-engineering` skill
   records authorization, scaffolds the session folder, and walks you through triage with
   reviewed plans. Resume later with *"continue the investigation."*

## Safety

- **Static by default** — triage and static analysis only read bytes.
- **Dynamic only in a sandbox** — running an untrusted target needs your consent **and**
  isolation (no-network container / throwaway VM / microVM), never the host.
- **Authorized targets only** (CTF / owned / authorized engagement); the harness records it.
- Recovered secrets/IOCs stay local — never sent to external services.

## More

- **Full workflow & design:** `ARCHITECTURE.md`
- **Install:** `INSTALL.md`
- **Air-gapped deployment** (`vibe-reverse` Docker image): `deploy/` (`sh deploy/build.sh`) —
  bakes every tool (Ghidra / radare2 / angr / z3 / capa / FLOSS / qiling / `rustc` / …)
  and detonates malware only in a no-network microVM.
- **Design specs & build history:** `docs/superpowers/`
- **Status:** 14 skills, built & tested (deterministic suite + RED→GREEN scenario tests).
  Roadmap: whitebox crypto, `re-diff`, and firmware / managed / wasm target packs.
