#!/usr/bin/env sh
# setup.sh — install every external tool the RE harness uses.
#   * system tools via your OS package manager (apt or brew), best-effort
#   * Python tools (angr, z3, ...) into a stdlib venv at $RE_HARNESS_VENV
# Idempotent; safe to re-run. Review before running — it installs software.
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
VENV="${RE_HARNESS_VENV:-$HOME/.local/share/re-harness/venv}"

echo "==> system tools"
SYS_APT="file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd yara build-essential \
zip unzip p7zip-full unar cabextract xz-utils zstd lz4 lzip libarchive-tools cpio \
ssdeep openssl jq ripgrep poppler-utils libimage-exiftool-perl less tree"
SYS_BREW="binutils binwalk radare2 gdb upx"   # macOS: ltrace/strace/xxd differ or are built-in
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update && sudo apt-get install -y $SYS_APT
elif command -v brew >/dev/null 2>&1; then
  brew install $SYS_BREW || true
else
  echo "  no apt/brew detected — install these yourself: $SYS_APT" >&2
fi

echo "==> python tools in a venv ($VENV)"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip
"$VENV/bin/pip" install -r "$DIR/python-tools.txt"

echo "==> Ghidra (manual — large; not auto-installed)"
cat <<'GHIDRA'
  1) install a JDK 21:   sudo apt-get install -y openjdk-21-jdk unzip wget
                         (macOS: brew install openjdk@21)
  2) download:           https://github.com/NationalSecurityAgency/ghidra/releases
  3) unzip and add ghidra_*/support to PATH (provides analyzeHeadless)
GHIDRA

cat <<'STANDALONE'
==> standalone tools (not pip; fetch manually if you want them on a host)
  capa  : https://github.com/mandiant/capa/releases       (standalone linux zip)
  FLOSS : https://github.com/mandiant/flare-floss/releases (standalone linux zip)
  DIE   : https://github.com/horsicq/DIE-engine/releases   (diec CLI)
STANDALONE

cat <<EOF

Done.
  Python tools: $VENV/bin/python  (angr, z3, ...)
  The harness auto-uses this venv. If you chose a custom path, add to your shell rc:
      export RE_HARNESS_VENV="$VENV"
EOF
