# RE tool cheat-sheet (which tool for what)

| Tool | Use it for |
|---|---|
| `file`, `xxd`, `strings` | first look: format, magic, embedded text |
| `readelf`, `objdump`, `nm` | ELF headers, sections, disassembly, symbols |
| `binwalk` | find/extract embedded files & filesystems; entropy (packing) |
| `radare2` / `rizin` | interactive disassembly & analysis, scripting (r2pipe) |
| Ghidra (`analyzeHeadless`) | decompilation to C; batch/scripted analysis |
| `upx` | detect/unpack UPX-packed binaries |
| `gdb`, `ltrace`, `strace` | dynamic: breakpoints, library/syscall traces (sandbox only) |
| `angr`, `z3` (python) | symbolic execution / constraint solving (keygen, paths) |
