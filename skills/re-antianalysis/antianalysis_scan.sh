#!/usr/bin/env sh
# antianalysis_scan.sh — flag common anti-analysis signatures (static). NEVER runs
# the target. String-based API checks + an optional objdump pass for rdtsc/cpuid.
# Usage: antianalysis_scan.sh <target> <out-dir>
set -eu
TARGET="${1:?usage: antianalysis_scan.sh <target> <out-dir>}"
OUT="${2:?usage: antianalysis_scan.sh <target> <out-dir>}"
ART="$OUT/artifacts/antianalysis"; mkdir -p "$ART"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }
REPORT="$ART/antianalysis.txt"
STR=$(strings -n 4 "$TARGET" 2>/dev/null || true)

check() { # <label> <regex>
  if printf '%s' "$STR" | grep -Eiq "$2"; then echo "[FLAG] $1"; else echo "[ ok ] $1"; fi
}
{
  echo "== anti-analysis scan: $TARGET =="
  check "anti-debug (ptrace/IsDebuggerPresent/TracerPid/NtQueryInformationProcess)" \
        'ptrace|IsDebuggerPresent|CheckRemoteDebugger|TracerPid|NtQueryInformationProcess|NtSetInformationThread'
  check "timing (GetTickCount/QueryPerformanceCounter/timeGetTime)" \
        'GetTickCount|QueryPerformanceCounter|timeGetTime'
  check "anti-VM (VBox/VMware/QEMU/Xen/VirtualBox)" \
        'vbox|vmware|qemu|xen|virtualbox'
  check "anti-sandbox (sbiedll/sandboxie/wine)" \
        'sbiedll|sandboxie|wine_get'
  check "self-integrity / anti-dump (VirtualProtect/checksum/crc)" \
        'VirtualProtect|NtProtectVirtualMemory|checksum|crc32'
  if command -v objdump >/dev/null 2>&1; then
    DIS=$(objdump -d "$TARGET" 2>/dev/null || true)
    printf '%s' "$DIS" | grep -qiw 'rdtsc' && echo "[FLAG] rdtsc instruction (timing-based)" || echo "[ ok ] rdtsc instruction"
    printf '%s' "$DIS" | grep -qiw 'cpuid' && echo "[FLAG] cpuid instruction (VM detection)" || echo "[ ok ] cpuid instruction"
  fi
} | tee "$REPORT"
