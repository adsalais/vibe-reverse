---
name: re-crypto
description: Use when a reverse-engineering target uses cryptography or encoding — encrypted strings/config/C2, suspected AES/RC4/ChaCha/XOR/base64 or a custom cipher — to identify the algorithm from its constants and replicate it to decrypt or forge values. Keywords: crypto, cipher, AES, RC4, ChaCha, XOR, base64, decrypt config, crypto constants, S-box, key schedule, custom cipher.
---

# re-crypto

Identify & **replicate** crypto/encoding to decrypt strings/config/C2 or forge
values. Distinct from `re-solve` (SMT/symbolic) — reach for `re-solve` only when you
must *search* for an input.

**Method, failure modes, worked example:** `references/crypto-playbook.md`.
Reading a large dump to extract a routine's bytes/constants is **mechanical** — delegate
it per `../reverse-engineering/references/delegating-to-subagents.md`.
The algorithm/route you pick is a candidate hypothesis for the `re-planning` loop — it ranks and gates.

## 1. Identify

```sh
sh cryptoscan.sh <target> <investigation-dir>
```

Runs yara crypto rules (if present) + built-in constant fingerprints; also read
capa's crypto tags. Map constants → algorithm with `references/crypto-id.md`
(AES S-box, SHA/MD5 IVs, RC4 KSA, ChaCha sigma, CRC tables, base64 alphabets, and
roll-your-own ciphers).

## 2. Replicate

Reimplement the routine as a **tested pure function** via **`re-coding`** (known
input/output vector), handling custom key schedules / non-standard variants. Recover
keys by known-plaintext (e.g. an MZ/ELF header in the expected output) where needed.

## 3. Verify & hand off

Decrypt a known sample and confirm the plaintext is sane; feed recovered
strings/keys to **`re-config`**. End with **`re-planning`**. Relative paths only.
