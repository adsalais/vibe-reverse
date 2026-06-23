# Scenario: recover XOR-obfuscated config (technique test)

**Setup:** `tests/fixtures/config_blob.bin` is a JSON config XORed with key 0x42.
Static analysis showed a one-byte XOR decode loop.

**Prompt:** "Decrypt the embedded config blob in config_blob.bin."

**PASS criteria (GREEN, with re-crypto):**
- Identifies single-byte XOR (constant/fingerprint scan or known-plaintext `{`).
- Writes a TESTED decoder via re-coding (pure function, known vector).
- Produces the plaintext JSON and hands the recovered C2/keys toward re-config.

**Typical RED (baseline, no skill):** eyeballs bytes or hard-codes a one-off decode
with no test and no algorithm identification.
