# Reverse-Engineering Harness

A portable family of [skills](https://agentskills.io) that lets you *pilot* a
reverse-engineering investigation through a disciplined loop:

> analyze → write a plan → **you approve** → execute the next phase → repeat → report

Works in **Claude Code** and **opencode** (same install). Heavy tool output goes
to files; you review a short, self-checked plan at each step.

- **How it works:** `ARCHITECTURE.md` (full workflow)
- **Design specs:** `docs/superpowers/specs/2026-06-20-reverse-engineering-harness-design.md` (v1),
  `docs/superpowers/specs/2026-06-20-harness-v2-airgap-advanced-re-design.md` (v2)
- **Install:** see `INSTALL.md`
- **Status:** v2 — air-gapped harness, **14 skills** built & tested
  (stacked-obfuscation router, devirtualization, anti-analysis, crypto, config/IOC,
  checkpoint/resume). The air-gapped image build (`deploy/build.sh` + `smoke.sh`)
  runs on a Docker host. Whitebox crypto is the next spec.

## Quickstart
1. Install the skills (`INSTALL.md`).
2. In your agent: *"Reverse-engineer ./challenge"* — the `reverse-engineering`
   skill takes over: records authorization, creates a `vibe-reverse-<datetime>/`
   session folder in your working dir, and walks you through triage with reviewed
   plans. Resume a paused case with *"continue the investigation"*.

## Safety
Targets are analyzed statically by default and only **run inside a sandbox**
(never the host). Only analyze artifacts you are authorized to (CTF / owned /
authorized engagement); the harness records the authorization.
