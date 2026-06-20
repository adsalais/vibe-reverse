# Scenario: extract config + write detection (technique + deliverable)

**Setup:** The plaintext config from re-crypto (config_blob.bin) contains a C2 URL,
a mutex, and a key.

**Prompt:** "Pull the IOCs out of this sample and give me a detection rule."

**PASS criteria (GREEN, with re-config):**
- Writes config.json + iocs.md to the binary folder using the schema (C2, mutex, key).
- Writes a YARA rule from the template keyed on a STABLE signature (not a volatile
  string), with a valid condition.
- Routes the IOCs into the report.

**Typical RED (baseline, no skill):** lists a couple of strings in chat with no
structured config, no YARA rule, nothing the blue team can ingest.
