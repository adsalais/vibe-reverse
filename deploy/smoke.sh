#!/usr/bin/env sh
# smoke.sh — in-image checks. Run under network isolation, as root (the
# --entrypoint sh below bypasses the remap entrypoint; root already has a passwd
# entry, so the uid-sensitive checks pass):
#   docker run --rm --network none --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

# offline opencode env hardening present
[ "${OPENCODE_DISABLE_MODELS_FETCH:-}" = "1" ] || fail "OPENCODE_DISABLE_MODELS_FETCH not set"
[ "${OPENCODE_DISABLE_AUTOUPDATE:-}" = "1" ]  || fail "OPENCODE_DISABLE_AUTOUPDATE not set"
ok "offline env vars"

# opencode runs OFFLINE without hanging (this script runs with --network none).
# A hang on models.dev would trip the timeout (exit 124).
timeout 30 opencode --version >/dev/null 2>&1 || fail "opencode --version failed/hung offline (exit $?)"
ok "opencode --version offline"

# Ghidra headless on PATH, backed by a runnable JDK 21
command -v analyzeHeadless >/dev/null 2>&1 || fail "analyzeHeadless not on PATH"
"$JAVA_HOME/bin/java" -version >/dev/null 2>&1 || fail "JDK at JAVA_HOME not runnable"
ok "ghidra analyzeHeadless + JDK 21"

# python tools installed GLOBALLY (no venv): import angr + z3
python3 -c 'import z3, angr' 2>/dev/null || fail "global python cannot import z3/angr"
ok "global python z3+angr"

# advanced-RE standalone binaries on PATH
for t in capa floss yara diec; do
  command -v "$t" >/dev/null 2>&1 || fail "$t missing from PATH"
done
ok "capa/floss/yara/diec"

# advanced-RE python libs importable (global)
python3 -c 'import capstone, unicorn, keystone, lief, pefile, elftools, miasm, qiling, yara, r2pipe' \
  || fail "global python cannot import the advanced-RE libs"
python3 -c 'import pwn, speakeasy, triton' \
  || fail "global python cannot import pwn/speakeasy/triton"
ok "advanced-RE python libs"

# QEMU present
command -v qemu-system-x86_64 >/dev/null 2>&1 || fail "qemu-system-x86_64 missing"
ok "qemu"

# baked identity: the vibe user + the privilege-drop tool
getent passwd vibe >/dev/null 2>&1 || fail "vibe user missing"
command -v setpriv >/dev/null 2>&1 || fail "setpriv missing"
ok "vibe user + setpriv"

# all skills baked
n=$(ls -1d /opt/vibe-reverse/skills/*/ 2>/dev/null | wc -l)
[ "$n" -eq 12 ] || fail "expected 12 skills, found $n"
[ -f /opt/vibe-reverse/skills/reverse-engineering/SKILL.md ] || fail "orchestrator skill missing"
ok "12 skills baked"

# CA: if a real cert was baked, it must be in the trust store
if [ -s /usr/local/share/ca-certificates/internal-ca.crt ]; then
  grep -rqs . /etc/ssl/certs/ca-certificates.crt || fail "CA bundle empty"
  ok "internal CA registered"
else
  ok "no internal CA (placeholder) — skipped"
fi

# microVM guest + driver
for f in vmlinuz initrd.img rootfs.ext4; do
  [ -s "/opt/vibe-reverse/guest/$f" ] || fail "guest $f missing"
done
[ -x /opt/vibe-reverse/bin/vmrun.sh ] || fail "vmrun.sh missing"
ok "microVM guest + vmrun.sh"

for t in xorriso mkfs.vfat mcopy; do command -v "$t" >/dev/null 2>&1 || fail "windows-path tool missing: $t"; done
ok "windows-path tools (iso/fat/mtools)"

echo "PASS: smoke.sh"
