---
name: re-config
description: Use when extracting a malware sample's configuration and indicators of compromise — C2 servers, mutexes, keys, campaign IDs, persistence — and producing a blue-team deliverable (IOC list + YARA rule). Keywords: malware config, IOC, C2, indicators, extract config, YARA rule, mutex, campaign id, persistence, detection.
---

# re-config

Turn recovered data into a **defender deliverable** — `config.json` + `iocs.md` +
a **YARA rule**, written into the binary's folder.

**Method, failure modes, worked example:** `references/config-playbook.md`.
Reading a large strings/FLOSS dump to extract IOC candidates is **mechanical** — delegate
it per `../reverse-engineering/references/delegating-to-subagents.md`.
The sources/fields you pursue are candidate hypotheses for the `re-planning` loop — it ranks and gates.

## Sources

Decrypted strings/config from **`re-crypto`** / FLOSS, config structs from
**`re-static`**, and runtime/emulation dumps from **`re-dynamic`** (qiling).

## Extract

Populate the `references/ioc-schema.md` shape: C2 (URLs/IPs/domains/ports),
campaign/botnet IDs, mutexes, keys, persistence, registry, files, user-agents,
kill-switch, hashes. Write `config.json` + a defender-friendly `iocs.md`.

## Detect

Author a YARA rule from `references/yara-template.yar`, keyed on **stable**
signatures (decryptor bytes, unique constants, config markers) — avoid brittle,
volatile strings. Sanity-check with `yara <rule> <sample>` if available.

Feed the IOCs + rule into the report's IOC section (`re-report`). End with
**`re-planning`**. Relative paths only.
