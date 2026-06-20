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

You are on an air-gapped network: every tool above is already installed. Never try
to install anything. If a tool seems missing, it is a PATH/usage issue.
