---
name: re-deobfuscate
description: Use when triage or static analysis shows a binary is packed or obfuscated — high entropy, a packer signature (UPX), encrypted strings, or control-flow flattening — to unpack and deobfuscate before deeper analysis. Keywords: packed, UPX, unpack, deobfuscate, obfuscation, entropy, encrypted strings, control-flow flattening.
---

# re-deobfuscate

Make the code readable before deeper analysis.

## Known packers

```sh
sh unpack.sh <target> <investigation-dir>
```

Detects/unpacks UPX. If `upx` is missing, install via **`re-preflight`**, then re-run.

## Nested layers

After unpacking, **re-run `re-triage` and `re-static` on the unpacked artifact.**
Repeat until entropy is normal and the code is readable (packers nest).

## Custom deobfuscation

For encrypted strings or control-flow flattening, write a **tested** decoder via
**`re-scripting`**, apply it, then re-run triage/static on the result.

Static only here — runtime unpacking belongs to `re-dynamic` (sandboxed). End with
**`re-planning`**. Relative paths only.
