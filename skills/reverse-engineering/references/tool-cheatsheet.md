# RE tool cheat-sheet (which tool for what) — all tools are pre-installed (air-gapped)

| Tool | Use it for |
|---|---|
| `file`, `xxd`, `strings` | first look: format, magic, embedded text |
| `readelf`, `objdump`, `nm` | ELF headers, sections, disassembly, symbols |
| `binwalk` | find/extract embedded files & filesystems; entropy (packing) |
| Detect-It-Easy (`diec`) | precise packer/compiler/protector identification |
| `radare2` / `r2` | interactive disassembly & analysis, scripting (r2pipe) |
| Ghidra (`analyzeHeadless`) | decompilation to C; batch/scripted analysis |
| `upx` | detect/unpack UPX-packed binaries |
| `capa` | identify program capabilities (ATT&CK, MBC) from a binary |
| FLOSS (`floss`) | automatically deobfuscate/extract obfuscated + stack strings |
| `yara` | match signatures/crypto/packer rules; generate detections |
| `gdb`, `ltrace`, `strace` | dynamic: breakpoints, library/syscall traces (sandbox only) |
| `angr`, `z3` (python) | symbolic execution / SMT (keygen, paths, constraints) |
| `capstone`/`keystone`/`unicorn` (python) | disassemble / assemble / emulate (patching, deobf) |
| `miasm`, Triton (python) | IR, taint, symbolic — control-flow deobf & devirtualization |
| `qiling` (python) | full-system-lite emulation: unpack, config-extract without detonating |
| `lief`, `pefile`, `pyelftools` (python) | parse/modify PE/ELF/Mach-O |

**General utilities (also pre-installed):**

| Tool | Use it for |
|---|---|
| `7z`, `unzip`, `zip`, `unar`, `cabextract`, `bsdtar` (libarchive-tools) | extract/repack archives (incl. password-protected, RAR, CAB) |
| `xz`, `zstd`, `lz4`, `lzip`, `cpio` | (de)compress common container formats |
| `ssdeep` | fuzzy hashing — malware similarity / variant clustering |
| `openssl` | hashing, base64, decrypt, cert/key parsing (pairs with `re-crypto`) |
| `jq` | query/transform JSON (e.g. `config.json` / IOC output) |
| `rg` (ripgrep) | fast search across decompiled output / strings / artifacts |
| `pdftotext`, `pdfinfo` (poppler-utils) | PDF maldoc triage |
| `exiftool` | metadata from documents / images |
| `olevba`, `oleid`, `rtfobj` (oletools) | Office / RTF macro & OLE maldoc analysis |
| `less`, `tree` | page output / view the investigation tree |

You are on an air-gapped network: every tool above is already installed. Never try
to install anything. If a tool seems missing, it is a PATH/usage issue.
