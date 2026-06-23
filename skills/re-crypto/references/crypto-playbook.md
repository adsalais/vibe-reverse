# Crypto playbook — identify, replicate, verify

Identify the cipher/encoding and **replicate it as tested code** to decrypt
strings/config/C2 — don't reverse it by hand. Distinct from `re-solve` (reach for that
only when you must *search* for an input).

## Method

1. **Identify** — `cryptoscan.sh` + capa crypto tags; map constants → algorithm with
   `crypto-id.md` (sibling reference: AES S-box, SHA/MD5 IVs, RC4 KSA, ChaCha sigma, CRC
   tables, base64 alphabets, roll-your-own).
2. **Replicate** as a **tested pure function** via `re-coding` (known input/output
   vector); handle custom key schedules / non-standard variants. Recover keys by
   known-plaintext (e.g. an `MZ`/`\x7fELF` header in the expected output) where needed.
3. **Verify** — decrypt a known sample, confirm the plaintext is sane; feed recovered
   strings/keys to `re-config`.

## Failure modes / wrong-track signals

- **Over-assuming AES** — a lone repeating-key XOR is the most common malware "crypto";
  match the constants before naming the algorithm.
- **Missed custom key schedule** — a standard cipher with a tweaked schedule decrypts to
  garbage; replicate the *actual* schedule.
- **Not verifying** — "it's RC4" is `[likely]` until a known vector decrypts cleanly.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "256-byte table, must be AES" | Match the S-box constants (`crypto-id.md`); could be RC4/custom. `[likely]` until verified. |
| "I'll reverse the cipher by hand" | Replicate it as a tested function — hand-derivation is error-prone. |
| "Decryptor runs, ship it" | Verify against a known-plaintext vector first. |

## Have I understood enough?

Done when a **tested decryptor reproduces known plaintext** and keys are recovered with
evidence. Hand the plaintext/keys to `re-config`.

## Worked example

`cryptoscan.sh` finds a 256-byte identity array permuted by `j=(j+S[i]+key[i])` → RC4 KSA
(`crypto-id.md`). Replicate RC4 as a tested function (`re-coding`), key from a known
config header. Decrypt → a readable C2 URL appears (the sanity check) → **[confirmed]**,
hand to `re-config`.
