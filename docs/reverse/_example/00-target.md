# 00 — Target — crackme1

- **File:** tests/fixtures/crackme1
- **sha256:** 4d14084284560339cf6a05b90aa048467fc1fd1c381e1b51033edb408c0ef9eb
- **Size:** 16136 bytes
- **Source:** in-house CTF-style fixture (built from tests/fixtures/crackme1.c)
- **Goal:** find a `<key>` the binary accepts for a given `<user>`.

## Authorization / scope
- [x] I am authorized to analyze this (in-house fixture, authored for this repo).
- Notes: safe, self-contained; no network or external interaction.

## Dynamic analysis
- Sandbox used: not required (static analysis + a direct solve sufficed).
