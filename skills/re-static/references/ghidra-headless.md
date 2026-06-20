# Ghidra headless (analyzeHeadless)

`ghidra_decompile.sh` uses Ghidra when `analyzeHeadless` is on PATH:

    analyzeHeadless <proj-dir> tmp -import <target> \
      -scriptPath skills/re-static -postScript decompile_export.py

`decompile_export.py` (a Ghidra Python script, added when Ghidra support is
finalized) walks the program's functions, runs the DecompInterface, and writes C
to the path in env var `GHIDRA_OUT_C`. Until then the script falls back to
radare2, then objdump. Install Ghidra via `re-preflight` (needs a JDK).
