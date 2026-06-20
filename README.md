# Reverse-Engineering Harness

A portable family of [skills](https://agentskills.io) that lets you *pilot* a
reverse-engineering investigation through a disciplined loop:

> analyze → write a plan → **you approve** → execute the next phase → repeat → report

Works in **Claude Code** and **opencode** (same install). Heavy tool output goes
to files; you review a short, self-checked plan at each step.

- **Design spec:** `docs/superpowers/specs/2026-06-20-reverse-engineering-harness-design.md`
- **Install:** see `INSTALL.md`
- **Status:** v1 spine built (orchestrator, preflight, planning+self-review gate, scripting). Native phases next.

## Quickstart
1. Install the skills (`INSTALL.md`).
2. In your agent: *"Reverse-engineer ./challenge"* — the `reverse-engineering`
   skill takes over: checks tooling, creates `docs/reverse/<date>-<slug>/`, and
   walks you through triage with reviewed plans.

## Safety
Targets are analyzed statically by default and only **run inside a sandbox**
(never the host). Only analyze artifacts you are authorized to (CTF / owned /
authorized engagement); the harness records the authorization.
