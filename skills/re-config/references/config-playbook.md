# Config & IOC playbook — the defender deliverable

Turn recovered data into a blue-team deliverable: `config.json` (machine) + `iocs.md`
(human) + a YARA rule, in the binary's folder.

## Method

1. **Gather** — decrypted strings/config from `re-crypto`/FLOSS, config structs from
   `re-static`, runtime/emulation dumps from `re-dynamic`.
2. **Extract** into the `ioc-schema.md` shape (sibling reference): C2, campaign/botnet IDs,
   mutexes, keys, persistence, registry, files, user-agents, kill-switch, hashes. Write
   `config.json` + a defender-friendly `iocs.md`.
3. **Detect** — author a YARA rule from `yara-template.yar` (sibling reference) keyed on
   **stable** signatures (decryptor bytes, unique constants, config markers);
   sanity-check with `yara <rule> <sample>`. Feed IOCs + rule to `re-report`.

## Failure modes / wrong-track signals

- **Brittle YARA** — keying on volatile strings (paths, version tags) that change per
  build. Key on stable bytes (the decryptor stub, a unique constant).
- **Decoy/sinkhole C2** — a hardcoded host may be a decoy or already sinkholed; tag
  confidence rather than asserting it's live.
- **Missing a field** — a config blob often holds more than the C2 (mutex, campaign,
  kill-switch); walk the whole struct.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "YARA on this nice string" | Volatile strings make brittle rules — key on stable bytes. |
| "Found the C2, it's live" | Could be a decoy/sinkhole — tag `[likely]` unless confirmed dynamically. |
| "Got the C2, done" | Walk the whole config — mutex, campaign id, persistence, kill-switch. |

## Have I understood enough?

Done when `config.json` + `iocs.md` are populated from the recovered data and a
sanity-checked YARA rule keyed on stable signatures exists. Hand to `re-report`.

## Worked example

A decrypted blob (from `re-crypto`) yields `host=evil.example:443`, a mutex, and a
campaign id. Populate `config.json` (`ioc-schema.md`), write `iocs.md`, author a YARA rule
on the **decryptor's byte pattern** (stable) rather than the C2 string (volatile). Tag the
C2 `[likely]` pending a dynamic callback.
