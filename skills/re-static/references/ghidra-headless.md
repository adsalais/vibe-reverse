# Ghidra headless (analyzeHeadless)

`ghidra_decompile.sh` uses Ghidra when `analyzeHeadless` is on PATH:

    analyzeHeadless <proj-dir> tmp -import <target> \
      -scriptPath skills/re-static -postScript DecompileExport.java

`DecompileExport.java` (a Ghidra Java script, co-located so `-scriptPath` finds
it) walks the program's functions, runs the `DecompInterface`, and writes C to
the path in env var `GHIDRA_OUT_C`. If Ghidra is absent the script falls back to
radare2, then objdump. Install Ghidra via `re-preflight`.

## Requirements (Ghidra 12.x)

- **JDK 21** — Ghidra 12 requires JDK 21 (not 17). With an older/missing JDK,
  `analyzeHeadless` aborts with *"Unable to prompt user for JDK path, no TTY
  detected."* Point `JAVA_HOME` at a JDK 21 (the `vibe-reverse` image bakes
  Temurin 21 and sets this).
- **A full JDK, not a JRE** — Ghidra compiles `.java` scripts in-process, which
  needs `javac` (present in a JDK, absent in a JRE).
- **Java scripts, not Python** — Ghidra 12 removed the bundled Jython; `.py`
  scripts now require PyGhidra (CPython + JPype). Java GhidraScripts always work
  headless, so the decompiler script is `DecompileExport.java`.
- **A resolvable home directory** — the JVM derives `user.home` from the passwd
  database (via `getpwuid`), *not* `$HOME`. A container running as a mapped uid
  with no `/etc/passwd` entry gets `user.home="?"` and Ghidra fails with *"user
  home directory does not exist."* The image's entrypoint adds a passwd entry for
  the running uid (see `deploy/ensure-user.sh`).
