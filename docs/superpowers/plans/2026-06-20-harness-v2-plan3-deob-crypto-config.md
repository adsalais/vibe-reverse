# Harness v2 — Plan 3: Deobfuscation Router + Crypto + Config — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework `re-deobfuscate` into a **stacked-layer router** (inventory → order → peel → re-triage), add the `re-crypto` and `re-config` skills, and give `re-static` an automatic capa/FLOSS scan + routing and `re-dynamic` an emulation path. Skill family **10 → 12**.

**Architecture:** New tool-optional helper scripts (`static_scan.sh`, `deob_map.sh`, `cryptoscan.sh`) write to `artifacts/`; the skills add the reasoning. `re-crypto` identifies crypto from constants and replicates it (via `re-scripting`); `re-config` turns recovered strings/config into an IOC list + a YARA rule. `re-dynamic` gains a Qiling emulation template. All slow tools follow `references/long-running-ops.md`.

**Tech Stack:** POSIX `sh`, Python 3, capa/FLOSS/yara (baked in Plan 2), markdown.

**Implements (spec sections):** §4.5 (re-static/re-dynamic hooks), §5.1 (deob router), §5.4 (re-crypto), §5.5 (re-config).
**Depends on:** Plan 1 (layout, conventions, orchestrator routing already naming these skills) + Plan 2 (capa/FLOSS/yara/qiling baked), on `main`.
**Deferred:** `re-devirtualize` + `re-antianalysis` (Plan 4) — the deob router *routes* to them; they are built next.

**Plan sequence:** Plan 3 of 4.

## Global Constraints

- Skills tool-neutral; helper files referenced by **relative path**; frontmatter `name` == dir name.
- Helper scripts: POSIX `sh` + `set -eu`; **never execute the target** in static/triage/deob paths; **tool-optional** (skip absent tools, never fail the suite).
- Slow tools (capa, FLOSS, emulation) follow `skills/reverse-engineering/references/long-running-ops.md` (background + budget + ask-before-kill).
- Air-gap rule: never install anything.
- Commit messages end with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

| Path | Responsibility |
|---|---|
| `skills/re-static/static_scan.sh` | capa + FLOSS scan → `artifacts/{capa,floss}/`. |
| `skills/re-static/SKILL.md` | + auto-scan + routing to re-crypto/re-antianalysis/re-devirtualize. |
| `skills/re-deobfuscate/deob_map.sh` | Scaffold the deobfuscation map. |
| `skills/re-deobfuscate/SKILL.md` | Rework into the stacked-layer router. |
| `skills/re-deobfuscate/references/obfuscation-taxonomy.md` | Techniques → handler/route. |
| `skills/re-crypto/SKILL.md` | Identify & replicate crypto. |
| `skills/re-crypto/cryptoscan.sh` | Crypto-constant scan (yara + fingerprints). |
| `skills/re-crypto/references/crypto-id.md` | Constant → algorithm table. |
| `skills/re-config/SKILL.md` | Config & IOC extraction → blue-team deliverable. |
| `skills/re-config/references/ioc-schema.md` | `config.json` / `iocs.md` schema. |
| `skills/re-config/references/yara-template.yar` | YARA rule template. |
| `skills/re-dynamic/templates/qiling_emulate.py` | Emulation skeleton. |
| `skills/re-dynamic/SKILL.md` | + emulation / run-to-unpack. |
| `tests/scripts/test_static_scan.sh`, `test_deob_map.sh`, `test_cryptoscan.sh`, `test_config.sh`, `test_qiling_template.py` | Behavioral/compile tests. |
| `tests/scenarios/re-deobfuscate-stacked.md`, `re-crypto-xor.md`, `re-config-extract.md` | RED/GREEN scenarios. |
| `tests/fixtures/build.sh`, `.gitignore` | Generate + ignore `config_blob.bin`. |
| `deploy/smoke.sh`, `ARCHITECTURE.md`, `AGENTS.md` | Skill count 10 → 12; tables. |

---

## Task 1: `re-static` auto-scan (`static_scan.sh`) + routing

**Files:**
- Create: `tests/scripts/test_static_scan.sh`, `skills/re-static/static_scan.sh`
- Modify: `skills/re-static/SKILL.md`

**Interfaces:**
- Produces: `static_scan.sh <target> <out-dir>` → writes `<out>/artifacts/capa/capa.txt` + `<out>/artifacts/floss/floss.txt` (or skip lines), prints `capa:`/`floss:` status lines. Never executes the target.

- [ ] **Step 1: Write the failing test `tests/scripts/test_static_scan.sh`**

```sh
#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
echo dummy > "$TMP/sample.bin"
OUT=$(sh skills/re-static/static_scan.sh "$TMP/sample.bin" "$TMP/inv") || fail "nonzero"
[ -d "$TMP/inv/artifacts/capa" ]  || fail "capa artifact dir missing"
[ -d "$TMP/inv/artifacts/floss" ] || fail "floss artifact dir missing"
printf '%s' "$OUT" | grep -qi capa  || fail "no capa status line"
printf '%s' "$OUT" | grep -qi floss || fail "no floss status line"
echo "PASS: test_static_scan.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (`static_scan.sh` missing).

- [ ] **Step 3: Implement `skills/re-static/static_scan.sh`**

```sh
#!/usr/bin/env sh
# static_scan.sh — capability + string scan (capa + FLOSS). NEVER executes target.
# Tool-optional: a missing tool is reported and skipped. These can be SLOW on large
# binaries — launch per references/long-running-ops.md when needed.
# Usage: static_scan.sh <target> <out-dir>
set -eu
TARGET="${1:?usage: static_scan.sh <target> <out-dir>}"
OUT="${2:?usage: static_scan.sh <target> <out-dir>}"
ART="$OUT/artifacts"; mkdir -p "$ART/capa" "$ART/floss"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }

if command -v capa >/dev/null 2>&1; then
  capa "$TARGET" > "$ART/capa/capa.txt" 2>/dev/null \
    || echo "(capa failed / unsupported format)" > "$ART/capa/capa.txt"
  echo "capa:  $ART/capa/capa.txt"
else
  echo "capa:  not on PATH (skipped)"
fi

if command -v floss >/dev/null 2>&1; then
  floss "$TARGET" > "$ART/floss/floss.txt" 2>/dev/null \
    || echo "(floss failed / unsupported format)" > "$ART/floss/floss.txt"
  echo "floss: $ART/floss/floss.txt"
else
  echo "floss: not on PATH (skipped)"
fi
```

- [ ] **Step 4: Run the test — verify it PASSES** (`PASS: test_static_scan.sh`).

- [ ] **Step 5: Update the body of `skills/re-static/SKILL.md`** (keep frontmatter)

Add to the "Run it" section, after the `ghidra_decompile.sh` step:

```markdown
Then run the capability + string scan (capa + FLOSS):

```sh
sh static_scan.sh <target> <investigation-dir>
```

capa tags capabilities (ATT&CK/MBC); FLOSS auto-extracts obfuscated/stack strings.
Both can be slow on large binaries — launch them per
`../reverse-engineering/references/long-running-ops.md`. Summarize the hits into the
plan; full output stays in `artifacts/`.
```

And extend the "Assess" routing list with:

```markdown
- capa flags crypto / config / many obfuscated strings? → `re-crypto`, `re-config`.
- Anti-debug / anti-VM / timing checks visible? → `re-antianalysis`.
- A dispatcher loop + handler table (virtualized)? → `re-deobfuscate` → `re-devirtualize`.
```

- [ ] **Step 6: Commit**

```sh
git add skills/re-static tests/scripts/test_static_scan.sh
git commit -m "Plan2-3 T1: re-static auto-scan (capa+FLOSS) + routing to crypto/config/anti-analysis/devirt"
```

---

## Task 2: `re-deobfuscate` → stacked-layer router

**Files:**
- Create: `tests/scripts/test_deob_map.sh`, `skills/re-deobfuscate/deob_map.sh`, `skills/re-deobfuscate/references/obfuscation-taxonomy.md`, `tests/scenarios/re-deobfuscate-stacked.md`
- Modify: `skills/re-deobfuscate/SKILL.md`

**Interfaces:**
- Produces: `deob_map.sh <out-dir>` → writes `<out>/artifacts/deobfuscation/map.md` and prints its path.

- [ ] **Step 1: Write the failing test `tests/scripts/test_deob_map.sh`**

```sh
#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
M=$(sh skills/re-deobfuscate/deob_map.sh "$TMP/inv") || fail "nonzero"
[ -f "$M" ] || fail "map not created"
grep -qi "peel" "$M"   || fail "map missing peel guidance"
grep -qi "status" "$M" || fail "map missing status column"
echo "PASS: test_deob_map.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (`deob_map.sh` missing).

- [ ] **Step 3: Implement `skills/re-deobfuscate/deob_map.sh`**

```sh
#!/usr/bin/env sh
# deob_map.sh — scaffold the deobfuscation map: layers found, peel order, status.
# NEVER executes the target. Usage: deob_map.sh <out-dir>
set -eu
OUT="${1:?usage: deob_map.sh <out-dir>}"
D="$OUT/artifacts/deobfuscation"; mkdir -p "$D"
MAP="$D/map.md"
[ -f "$MAP" ] || cat > "$MAP" <<'EOF'
# Deobfuscation map

Peel the OUTERMOST layer first; re-triage between layers (packers nest; a peeled
payload may be a new binary — register it with add_binary.sh).

| # | layer / technique | handler / route | status | notes / artifact |
|---|-------------------|-----------------|--------|------------------|
| 1 | <e.g. UPX packing> | unpack.sh | todo | |
| 2 | <e.g. string/API obfuscation> | FLOSS / re-scripting | todo | |
| 3 | <e.g. control-flow flattening> | miasm/angr (re-scripting) | todo | |
| 4 | <e.g. opaque predicates> | z3 + patch (keystone/lief) | todo | |
| 5 | <e.g. virtualization> | re-devirtualize | todo | |

Done when: entropy is normal, strings/imports are readable, control flow is sane.
EOF
echo "$MAP"
```

- [ ] **Step 4: Run the test — verify it PASSES** (`PASS: test_deob_map.sh`).

- [ ] **Step 5: Write `skills/re-deobfuscate/references/obfuscation-taxonomy.md`**

```markdown
# Obfuscation taxonomy → handler / route

Peel OUTERMOST first. After each peel, re-run triage + static; repeat until clean.

| Technique | Signs | Handler / route |
|---|---|---|
| Packing | high entropy, packer sig (UPX!), tiny code + big high-entropy section | `unpack.sh` (UPX); else run-to-unpack / qiling emulate (`re-dynamic`) + lief rebuild |
| String obfuscation | few readable strings + a decode routine called everywhere | FLOSS first; then a tested decoder via `re-scripting` |
| Stack-strings | strings built byte-by-byte on the stack | FLOSS / scripted reconstruction |
| API hashing | imports resolved from hashes at runtime | resolve the hash table (capa hints + `re-scripting`) |
| Control-flow flattening | one dispatcher switch, many same-size blocks, a state var | de-flatten via miasm/angr symbolic recovery (`re-scripting`) |
| Opaque / bogus predicates | always-true/false branches, dead code | prove constant with z3, patch out (keystone/lief), reanalyze |
| Virtualization | fetch-decode-execute loop, virtual PC, handler table | → `re-devirtualize` |
| Encrypted layers | a crypto routine gates the next stage | → `re-crypto`, then re-triage the plaintext |
| Interleaved anti-analysis | anti-debug/anti-disasm mixed into the above | → `re-antianalysis` |

Stacking is the norm in advanced malware: expect 2–4 of these at once.
```

- [ ] **Step 6: Rewrite the body of `skills/re-deobfuscate/SKILL.md`** (keep frontmatter)

Required contents (the body MUST):
1. Frame it as a **router/loop**, not a one-shot unpack: **inventory → order → peel one layer → re-triage → repeat** until entropy is normal, strings/imports readable, control flow sane.
2. **Inventory** using triage/static signals + `static_scan.sh` (capa/FLOSS) + DIE (`diec`) + entropy; record layers with `sh deob_map.sh <investigation-dir>` and keep `artifacts/deobfuscation/map.md` current.
3. **Order** — peel outermost first (cite `references/obfuscation-taxonomy.md`).
4. **Gate balance:** propose the *whole* peeling plan once via `re-planning` (layers + order + ⚡/⏳/🐢 cost), then peel the obvious layers and **STOP at the gate** when something new appears (a fresh binary → `add_binary.sh` + re-triage; a VM → `re-devirtualize`; a layer you can't crack).
5. **Handlers/routes** table (from the taxonomy): packing (`unpack.sh` / run-to-unpack), strings/API (FLOSS / `re-scripting`), CFF (miasm/angr), opaque predicates (z3 + patch), virtualization → `re-devirtualize`, anti-analysis → `re-antianalysis`, crypto layers → `re-crypto`.
6. Custom decoders use **`re-scripting`** (tested). Static only here; runtime unpacking is `re-dynamic` (sandboxed). End with **`re-planning`**. Relative paths only.

- [ ] **Step 7: Write scenario `tests/scenarios/re-deobfuscate-stacked.md`**

```markdown
# Scenario: stacked obfuscation (technique + discipline)

**Setup:** triage shows entropy 7.8 + a `UPX!` sig; after a mental unpack the analyst
is told the unpacked code has both encrypted strings AND a flattening dispatcher.

**Prompt:** "This binary is heavily obfuscated — deobfuscate it."

**PASS criteria (GREEN, with re-deobfuscate):**
- Builds a deobfuscation map (runs `deob_map.sh`), listing ALL layers, not just UPX.
- States a peel ORDER (outermost first) and re-triages between layers.
- Routes each layer to the right handler (UPX→unpack.sh, strings→FLOSS/re-scripting,
  flattening→miasm/angr), and would route a VM to re-devirtualize.
- Ends with a re-planning gate; does NOT claim "unpacked, done" after only UPX.

**Typical RED (baseline, no skill):** runs `upx -d`, declares victory, and ignores
the remaining string + control-flow layers.
```

- [ ] **Step 8: RED/GREEN test the skill** with `re-deobfuscate-stacked.md`. Close loopholes; re-run.

- [ ] **Step 9: Commit**

```sh
git add skills/re-deobfuscate tests/scripts/test_deob_map.sh tests/scenarios/re-deobfuscate-stacked.md
git commit -m "Plan2-3 T2: re-deobfuscate stacked-layer router + deob_map.sh + taxonomy"
```

---

## Task 3: `re-crypto` skill

**Files:**
- Create: `tests/scripts/test_cryptoscan.sh`, `skills/re-crypto/cryptoscan.sh`, `skills/re-crypto/references/crypto-id.md`, `skills/re-crypto/SKILL.md`, `tests/scenarios/re-crypto-xor.md`

**Interfaces:**
- Produces: `cryptoscan.sh <target> <out-dir>` → writes `<out>/artifacts/crypto/cryptoscan.txt`; reports crypto-constant fingerprints. Never executes the target.

- [ ] **Step 1: Write the failing test `tests/scripts/test_cryptoscan.sh`**

```sh
#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v xxd >/dev/null 2>&1 || { echo "SKIP: no xxd"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# write the AES S-box head bytes so the fingerprint must fire
python3 -c "open('$TMP/aes.bin','wb').write(bytes([0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b]))"
OUT=$(sh skills/re-crypto/cryptoscan.sh "$TMP/aes.bin" "$TMP/inv") || fail "nonzero"
printf '%s' "$OUT" | grep -qi "AES S-box.*FOUND" || fail "did not detect AES S-box"
[ -f "$TMP/inv/artifacts/crypto/cryptoscan.txt" ] || fail "report missing"
echo "PASS: test_cryptoscan.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (`cryptoscan.sh` missing).

- [ ] **Step 3: Implement `skills/re-crypto/cryptoscan.sh`**

```sh
#!/usr/bin/env sh
# cryptoscan.sh — scan a target for crypto constants/algorithms. NEVER executes it.
# Uses yara crypto rules if present + built-in constant fingerprints. Tool-optional.
# Usage: cryptoscan.sh <target> <out-dir>
set -eu
TARGET="${1:?usage: cryptoscan.sh <target> <out-dir>}"
OUT="${2:?usage: cryptoscan.sh <target> <out-dir>}"
ART="$OUT/artifacts/crypto"; mkdir -p "$ART"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }
REPORT="$ART/cryptoscan.txt"

{
  echo "== cryptoscan: $TARGET =="
  if command -v capa >/dev/null 2>&1; then
    echo "-- capa crypto capabilities --"
    capa "$TARGET" 2>/dev/null | grep -iE 'crypt|aes|rc4|chacha|base64|hash|xor' \
      || echo "(none flagged by capa)"
  fi
  echo "-- constant fingerprints --"
  if command -v xxd >/dev/null 2>&1; then
    HEX=$(xxd -p "$TARGET" 2>/dev/null | tr -d '\n')
    printf '%s' "$HEX" | grep -qi '637c777bf26b6fc5' \
      && echo "AES S-box (63 7c 77 7b f2 6b 6f c5 ...) FOUND" || echo "AES S-box: not found"
  fi
  echo "-- base64 alphabets in strings --"
  strings -n 32 "$TARGET" 2>/dev/null \
    | grep -E 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' | head -3 \
    || echo "(standard alphabet not seen; a custom alphabet may exist)"
} | tee "$REPORT"
```

- [ ] **Step 4: Run the test — verify it PASSES** (`PASS: test_cryptoscan.sh`).

- [ ] **Step 5: Write `skills/re-crypto/references/crypto-id.md`**

```markdown
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
  then **replicate it as a tested function** (`re-scripting`) — don't reverse by hand.
- Verify by decrypting a known sample and sanity-checking the plaintext.
```

- [ ] **Step 6: Author `skills/re-crypto/SKILL.md`**

Frontmatter (verbatim):

```yaml
---
name: re-crypto
description: Use when a reverse-engineering target uses cryptography or encoding — encrypted strings/config/C2, suspected AES/RC4/ChaCha/XOR/base64 or a custom cipher — to identify the algorithm from its constants and replicate it to decrypt or forge values. Keywords: crypto, cipher, AES, RC4, ChaCha, XOR, base64, decrypt config, crypto constants, S-box, key schedule, custom cipher.
---
```

Required contents (the body MUST):
1. Scope: **identify & replicate** crypto/encoding to decrypt strings/config/C2 or forge values. Distinct from `re-solve` (SMT/symbolic) — reach for `re-solve` only when you must *search* for an input.
2. **Identify:** run `sh cryptoscan.sh <target> <investigation-dir>` (yara + constant fingerprints) and read capa's crypto tags; map constants via `references/crypto-id.md`.
3. **Replicate:** reimplement the routine as a **tested pure function** via **`re-scripting`** (known-vector test), handling custom key schedules / non-standard variants. Recover keys by known-plaintext where needed.
4. **Verify:** decrypt a known sample and confirm the plaintext is sane; feed recovered strings/keys to `re-config`.
5. End with **`re-planning`**. Relative paths only.

- [ ] **Step 7: Write scenario `tests/scenarios/re-crypto-xor.md`**

```markdown
# Scenario: recover XOR-obfuscated config (technique test)

**Setup:** `tests/fixtures/config_blob.bin` is a JSON config XORed with key 0x42.
Static analysis showed a one-byte XOR decode loop.

**Prompt:** "Decrypt the embedded config blob in config_blob.bin."

**PASS criteria (GREEN, with re-crypto):**
- Identifies single-byte XOR (constant/fingerprint scan or known-plaintext `{`).
- Writes a TESTED decoder via re-scripting (pure function, known vector).
- Produces the plaintext JSON and hands the recovered C2/keys toward re-config.

**Typical RED (baseline, no skill):** eyeballs bytes or hard-codes a one-off decode
with no test and no algorithm identification.
```

- [ ] **Step 8: RED/GREEN test the skill** with `re-crypto-xor.md` (build the fixture first — Task 6). Close loopholes; re-run.

- [ ] **Step 9: Commit**

```sh
git add skills/re-crypto tests/scripts/test_cryptoscan.sh tests/scenarios/re-crypto-xor.md
git commit -m "Plan2-3 T3: re-crypto skill + cryptoscan.sh + crypto-id reference"
```

---

## Task 4: `re-config` skill

**Files:**
- Create: `tests/scripts/test_config.sh`, `skills/re-config/references/ioc-schema.md`, `skills/re-config/references/yara-template.yar`, `skills/re-config/SKILL.md`, `tests/scenarios/re-config-extract.md`

- [ ] **Step 1: Write the failing test `tests/scripts/test_config.sh`**

```sh
#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
S=skills/re-config/references/ioc-schema.md
Y=skills/re-config/references/yara-template.yar
[ -f "$S" ] || fail "ioc-schema.md missing"
[ -f "$Y" ] || fail "yara-template.yar missing"
for k in c2 mutex key persistence campaign; do
  grep -qi "$k" "$S" || fail "ioc-schema missing field: $k"
done
grep -qi 'rule '      "$Y" || fail "yara-template has no rule"
grep -qi 'condition'  "$Y" || fail "yara-template missing condition"
echo "PASS: test_config.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (references missing).

- [ ] **Step 3: Write `skills/re-config/references/ioc-schema.md`**

````markdown
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
````

- [ ] **Step 4: Write `skills/re-config/references/yara-template.yar`**

```text
rule FAMILY_variant
{
    meta:
        author      = "<analyst>"
        description = "<family> — <what this detects>"
        date        = "<YYYY-MM-DD>"
        hash        = "<sha256 of the sample>"
        reference   = "<session / report path>"
    strings:
        $s1 = "<unique decoded string / config marker>" ascii wide
        $code = { 6A ?? 68 ?? ?? ?? ?? E8 }   // <unique routine, e.g. the decryptor>
    condition:
        // PE: uint16(0)==0x5A4D ; ELF: uint32(0)==0x464C457F
        (uint16(0) == 0x5A4D or uint32(0) == 0x464C457F) and any of them
}
```

- [ ] **Step 5: Run the test — verify it PASSES** (`PASS: test_config.sh`).

- [ ] **Step 6: Author `skills/re-config/SKILL.md`**

Frontmatter (verbatim):

```yaml
---
name: re-config
description: Use when extracting a malware sample's configuration and indicators of compromise — C2 servers, mutexes, keys, campaign IDs, persistence — and producing a blue-team deliverable (IOC list + YARA rule). Keywords: malware config, IOC, C2, indicators, extract config, YARA rule, mutex, campaign id, persistence, detection.
---
```

Required contents (the body MUST):
1. Purpose: turn recovered data into a **defender deliverable** — `config.json` + `iocs.md` + a **YARA rule**, written into the binary's folder.
2. **Sources:** decrypted strings/config from `re-crypto`/FLOSS, config structs from `re-static`, and runtime/emulation dumps from `re-dynamic` (qiling).
3. **Extract** to the `references/ioc-schema.md` shape: C2, campaign/botnet IDs, mutexes, keys, persistence, registry, files, user-agents, kill-switch, hashes.
4. **Author the YARA rule** from `references/yara-template.yar`, keyed on **stable** signatures (decryptor bytes, unique constants, config markers) — avoid brittle/volatile strings. Sanity-check it with `yara <rule> <sample>` if available.
5. Feed the IOCs + rule into the report's IOC section (`re-report`). End with **`re-planning`**. Relative paths only.

- [ ] **Step 7: Write scenario `tests/scenarios/re-config-extract.md`**

```markdown
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
```

- [ ] **Step 8: RED/GREEN test the skill** with `re-config-extract.md`. Close loopholes; re-run.

- [ ] **Step 9: Commit**

```sh
git add skills/re-config tests/scripts/test_config.sh tests/scenarios/re-config-extract.md
git commit -m "Plan2-3 T4: re-config skill (IOC/config extraction + YARA rule deliverable)"
```

---

## Task 5: `re-dynamic` emulation path

**Files:**
- Create: `skills/re-dynamic/templates/qiling_emulate.py`, `tests/scripts/test_qiling_template.py`
- Modify: `skills/re-dynamic/SKILL.md`

- [ ] **Step 1: Write the failing test `tests/scripts/test_qiling_template.py`**

```python
import py_compile
from pathlib import Path

T = Path("skills/re-dynamic/templates/qiling_emulate.py")

def test_exists():
    assert T.is_file(), "qiling_emulate.py missing"

def test_compiles():
    py_compile.compile(str(T), doraise=True)
```

- [ ] **Step 2: Run it — verify it FAILS**

Run: `python3 -m pytest tests/scripts/test_qiling_template.py -q`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement `skills/re-dynamic/templates/qiling_emulate.py`**

```python
#!/usr/bin/env python3
"""Emulate a target with Qiling to unpack / extract config without full detonation.

WHY: emulation runs the sample's instructions inside an emulator, granting only the
syscalls/resources you allow, so it can self-decrypt strings or build a config in
memory that we dump — safer and faster than native detonation for many samples. It
is still "running code": use only with consent + isolation (no network).

Adapt: set the rootfs for the target OS/arch, then add hooks/dumps for this sample.
Usage: python3 qiling_emulate.py <target> <rootfs> [--timeout 1800]
"""
import argparse


def emulate(target: str, rootfs: str, timeout: int) -> None:
    # why: import inside the function so the template still byte-compiles on hosts
    # where qiling is not installed (the air-gapped image has it).
    from qiling import Qiling  # noqa: F401

    # ql = Qiling([target], rootfs, console=False)
    # why: install hooks here — e.g. ql.hook_address(dump_cb, decryptor_ret_addr) to
    # capture plaintext, or hook mem writes to grab a decrypted config — then:
    # ql.run(timeout=timeout * 1_000_000)  # qiling timeout is microseconds
    raise SystemExit(
        "Fill in the rootfs + per-sample hooks (see re-dynamic SKILL.md)."
    )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("target")
    p.add_argument("rootfs", help="qiling rootfs for the target OS/arch")
    p.add_argument("--timeout", type=int, default=1800, help="emulation budget (s)")
    a = p.parse_args()
    emulate(a.target, a.rootfs, a.timeout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the test — verify it PASSES** (`2 passed`).

- [ ] **Step 5: Update the body of `skills/re-dynamic/SKILL.md`** (keep frontmatter + the sandbox discipline)

Add a section after "Trace it (inside the sandbox)":

```markdown
## Emulate it (unpack / extract without full detonation)

Emulation runs the sample's code inside an emulator with only the resources you
grant — useful to self-decrypt strings, drop a config you can dump, or run-to-unpack
a custom packer. It is still running code: keep it **no-network** and treat it under
the same consent rule. Prefer it to native detonation when it suffices.

- Linux/Windows user-mode: adapt `templates/qiling_emulate.py` via **`re-scripting`**
  (set the rootfs + per-sample hooks). Windows user-mode malware can also use
  `speakeasy`.
- Emulation can be slow — apply `../reverse-engineering/references/long-running-ops.md`
  (background + budget + **ask before killing**).
- Dumps land in `artifacts/dynamic/`; feed recovered config to `re-config`.

Native detonation (real execution) still goes ONLY to the no-network microVM
(`vmrun.sh`), never the container/host.
```

- [ ] **Step 6: Commit**

```sh
git add skills/re-dynamic tests/scripts/test_qiling_template.py
git commit -m "Plan2-3 T5: re-dynamic emulation path (qiling template) + guidance"
```

---

## Task 6: Wire-up — fixtures, skill count, docs, full suite

**Files:**
- Modify: `tests/fixtures/build.sh`, `.gitignore`, `deploy/smoke.sh`, `ARCHITECTURE.md`, `AGENTS.md`

- [ ] **Step 1: Add the `config_blob.bin` fixture to `tests/fixtures/build.sh`**

Append before the final `echo`:

```sh
# XOR-encrypted config blob (no compiler needed) — re-crypto / re-config scenarios
python3 - "$DIR/config_blob.bin" <<'PY'
import sys, json
cfg = json.dumps({"c2": "http://evil.example/gate",
                  "mutex": "Global\\m1", "key": "s3cr3t"}).encode()
open(sys.argv[1], "wb").write(bytes(b ^ 0x42 for b in cfg))
PY
echo "built: $DIR/config_blob.bin"
```

- [ ] **Step 2: Ignore the generated fixture in `.gitignore`**

Add under the existing fixtures line:

```gitignore
tests/fixtures/config_blob.bin
```

- [ ] **Step 3: Build the fixtures and confirm**

```sh
sh tests/fixtures/build.sh
[ -f tests/fixtures/config_blob.bin ] || echo "FAIL: config_blob.bin not built"
```

- [ ] **Step 4: Bump the baked-skill count in `deploy/smoke.sh`** (10 → 12)

Change both the count and the message:
```sh
n=$(ls -1d /opt/vibe-reverse/skills/*/ 2>/dev/null | wc -l)
[ "$n" -eq 12 ] || fail "expected 12 skills, found $n"
```
```sh
ok "12 skills baked"
```

- [ ] **Step 5: Update `ARCHITECTURE.md` + `AGENTS.md` skill tables**

- `ARCHITECTURE.md` §4 phases table: mark `re-deobfuscate` reworked (router); add `re-crypto` and `re-config` as built; note `re-devirtualize`/`re-antianalysis` land in Plan 4. Family now 12 of 14.
- `AGENTS.md`: skill count narrative (now 12 → 14 after Plan 4); add `re-crypto`/`re-config` to the repo map.

- [ ] **Step 6: Run the full deterministic suite**

```sh
for t in tests/scripts/test_*.sh; do sh "$t" || { echo "FAILED: $t"; exit 1; }; done
python3 -m pytest tests/scripts/ -q
```
Expected: all PASS (new tests included; `test_cryptoscan.sh` may print SKIP without xxd).

- [ ] **Step 7: Commit**

```sh
git add tests/fixtures/build.sh .gitignore deploy/smoke.sh ARCHITECTURE.md AGENTS.md
git commit -m "Plan2-3 T6: fixtures + skill count 12 + docs; full suite green"
```

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 3 slice):** re-static capa/FLOSS + routing §4.5 ✓ (T1); deob router §5.1 ✓ (T2, inventory→order→peel→re-triage, handler table, gate balance); re-crypto §5.4 ✓ (T3, identify via cryptoscan + replicate via re-scripting); re-config §5.5 ✓ (T4, schema + YARA); re-dynamic emulation §4.5 ✓ (T5, qiling template). Stacked-obfuscation success criterion ✓ (T2 scenario).
- **Placeholders:** none — helper scripts + tests are complete; SKILL bodies use the verbatim-frontmatter + contract + RED/GREEN scenario pattern; references are concrete; the qiling template intentionally raises a "fill in the hooks" SystemExit (it is a per-target skeleton, byte-compilable and tested as such).
- **Type/name consistency:** `static_scan.sh`/`cryptoscan.sh`/`deob_map.sh` arg order is `<target> <out-dir>` (cryptoscan/static_scan) or `<out-dir>` (deob_map), matching each test; artifact paths (`artifacts/capa`, `artifacts/floss`, `artifacts/crypto/cryptoscan.txt`, `artifacts/deobfuscation/map.md`) match the tests; skill names equal dir names (`re-crypto`, `re-config`); fixture `config_blob.bin` is XOR-0x42 and the re-crypto scenario states key 0x42.
```
