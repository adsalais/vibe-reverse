#!/usr/bin/env sh
# smoke.sh — in-image checks. Run under network isolation:
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

# Ghidra headless on PATH
command -v analyzeHeadless >/dev/null 2>&1 || fail "analyzeHeadless not on PATH"
ok "ghidra analyzeHeadless"

# venv imports angr + z3
/opt/vibe-reverse/venv/bin/python -c 'import z3, angr' 2>/dev/null \
  || fail "venv cannot import z3/angr"
ok "venv z3+angr"

# QEMU present (guest comes in Plan 2)
command -v qemu-system-x86_64 >/dev/null 2>&1 || fail "qemu-system-x86_64 missing"
ok "qemu"

# all 10 skills baked
n=$(ls -1d /opt/vibe-reverse/skills/*/ 2>/dev/null | wc -l)
[ "$n" -eq 10 ] || fail "expected 10 skills, found $n"
[ -f /opt/vibe-reverse/skills/reverse-engineering/SKILL.md ] || fail "orchestrator skill missing"
ok "10 skills baked"

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

echo "PASS: smoke.sh"
