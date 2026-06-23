# Crypto identification — constant → algorithm

| Constant / pattern | Algorithm |
|---|---|
| S-box starting `63 7c 77 7b f2 6b 6f c5` | AES (Rijndael) |
| Te0/Td0 256-entry 32-bit tables | AES T-tables (table-driven impl) |
| `67 45 23 01 / ef cd ab 89 / 98 ba dc fe / 10 32 54 76` | MD5 / SHA-1 init state |
| `6a09e667 bb67ae85 3c6ef372 a54ff53a` | SHA-256 init state |
| 256-byte identity array permuted in a loop `j = (j+S[i]+key[i%len])` | RC4 KSA |
| `expand 32-byte k` / `expand 16-byte k` | ChaCha / Salsa20 sigma |
| `edb88320` table | CRC-32 |
| `ABCD…XYZabc…789+/` (or a permuted variant) | Base64 (standard / custom alphabet) |

Tips:
- A lone repeating-key XOR is the most common malware "crypto" — find the key by
  known-plaintext (e.g. an MZ/ELF header in the plaintext) or frequency.
- Custom ciphers: identify the primitive (sub/xor/rot/add) and the key schedule,
  then **replicate it as a tested function** (`re-coding`) — don't reverse by hand.
- Verify by decrypting a known sample and sanity-checking the plaintext.
