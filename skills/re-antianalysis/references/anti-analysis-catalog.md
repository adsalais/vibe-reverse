# Anti-analysis catalog — technique → detection → bypass

| Technique | Detection signature | Bypass |
|---|---|---|
| ptrace self-attach (Linux) | `ptrace(PTRACE_TRACEME)`; fails if a debugger is attached | run without a debugger, or patch the check / force the return value in gdb |
| IsDebuggerPresent / PEB.BeingDebugged | `IsDebuggerPresent`, PEB byte read | patch the branch; set PEB byte 0; emulator lies |
| NtQueryInformationProcess(ProcessDebugPort) | the Nt call + a compare | hook/patch the return; qiling hook |
| /proc/self/status TracerPid (Linux) | opens status, parses `TracerPid:` | run untraced; or fake the file in the emulator |
| rdtsc timing | `rdtsc` pairs around a region, delta compared | patch out; emulator returns controlled TSC |
| cpuid hypervisor bit | `cpuid` leaf 1 ECX bit 31 / leaf 0x40000000 | emulator/hook returns bare-metal values |
| anti-VM artifacts | strings: VBox/VMware/QEMU, MAC OUI, registry keys, files | run on bare-metal-like sandbox; hook the queries |
| anti-disassembly | junk bytes, overlapping instructions, opaque jumps | force linear/correct disasm in r2/Ghidra; this is a deob layer → re-deobfuscate |
| TLS callbacks / early entry | code runs before `main` (PE TLS dir) | set breakpoints on TLS callbacks before run |
| self-integrity / checksum | hashes its own code; refuses if patched | patch after the check, or hook the verifier to pass |

Sandbox-evasion that just **sleeps**: skip the sleep (debugger/emulator) rather than
wait it out. When emulating with qiling, install hooks that make these checks lie.
