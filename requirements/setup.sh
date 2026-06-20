#!/usr/bin/env sh
# setup.sh — install every external tool the RE harness uses.
#   * system tools via your OS package manager (apt or brew), best-effort
#   * Python tools (angr, z3, ...) into a uv-managed venv at $RE_HARNESS_VENV
# Idempotent; safe to re-run. Review before running — it installs software.
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
VENV="${RE_HARNESS_VENV:-$HOME/.local/share/re-harness/venv}"

echo "==> system tools"
SYS_APT="file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd"
SYS_BREW="binutils binwalk radare2 gdb upx"   # macOS: ltrace/strace/xxd differ or are built-in
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update && sudo apt-get install -y $SYS_APT
elif command -v brew >/dev/null 2>&1; then
  brew install $SYS_BREW || true
else
  echo "  no apt/brew detected — install these yourself: $SYS_APT" >&2
fi

echo "==> uv"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

echo "==> python tools in a uv venv ($VENV)"
uv venv "$VENV"
uv pip install --python "$VENV/bin/python" -r "$DIR/python-tools.txt"

echo "==> Ghidra (manual — large; not auto-installed)"
cat <<'GHIDRA'
  1) install a JDK 17+:  sudo apt-get install -y openjdk-17-jdk unzip wget
                         (macOS: brew install openjdk)
  2) download:           https://github.com/NationalSecurityAgency/ghidra/releases
  3) unzip and add ghidra_*/support to PATH (provides analyzeHeadless)
GHIDRA

cat <<EOF

Done.
  Python tools: $VENV/bin/python  (angr, z3, ...)
  The harness auto-uses this venv. If you chose a custom path, add to your shell rc:
      export RE_HARNESS_VENV="$VENV"
EOF
