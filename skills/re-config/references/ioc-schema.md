# IOC / config schema

Write `config.json` (machine) + `iocs.md` (human) into the binary's folder.

```json
{
  "family": "",
  "version": "",
  "campaign_id": "",
  "c2": [{ "host": "", "port": 0, "protocol": "" }],
  "mutexes": [],
  "keys": [{ "type": "xor|rc4|aes|...", "value": "" }],
  "persistence": [],
  "registry": [],
  "files": [],
  "user_agents": [],
  "kill_switch": "",
  "hashes": { "sha256": "" }
}
```

`iocs.md` lists the same in a defender-friendly table (indicator · type · context),
plus the generated YARA rule.
