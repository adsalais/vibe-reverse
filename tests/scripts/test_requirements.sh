#!/usr/bin/env sh
# Validates the requirements/ install artifacts and the uv-venv convention.
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }

# python-tools.txt lists the expected tools
[ -s requirements/python-tools.txt ] || fail "python-tools.txt missing/empty"
grep -qi 'z3'   requirements/python-tools.txt || fail "python-tools.txt missing z3"
grep -qi 'angr' requirements/python-tools.txt || fail "python-tools.txt missing angr"

# setup.sh is valid POSIX sh and uses uv + the venv var
sh -n requirements/setup.sh || fail "setup.sh syntax error"
grep -q 'uv venv'         requirements/setup.sh || fail "setup.sh missing 'uv venv'"
grep -q 'RE_HARNESS_VENV' requirements/setup.sh || fail "setup.sh missing RE_HARNESS_VENV"

# Dockerfile has the key instructions
for kw in '^FROM ' 'uv' 'python-tools.txt' 'RE_HARNESS_VENV'; do
  grep -q "$kw" requirements/Dockerfile || fail "Dockerfile missing: $kw"
done

# uv can build a venv whose python the harness convention resolves
if command -v uv >/dev/null 2>&1; then
  ROOT="$(mktemp -d)"; V="$ROOT/venv"
  if uv venv "$V" >/dev/null 2>&1 && [ -x "$V/bin/python" ]; then
    PY=$(RE_HARNESS_VENV="$V" sh -c 'V="${RE_HARNESS_VENV:-$HOME/.local/share/re-harness/venv}"; if [ -x "$V/bin/python" ]; then echo "$V/bin/python"; else echo python3; fi')
    [ "$PY" = "$V/bin/python" ] || fail "venv-python resolution did not pick the venv"
  else
    echo "(uv venv unavailable offline — skipped live venv check)"
  fi
  rm -rf "$ROOT"
else
  echo "(uv absent — skipped live venv check)"
fi

echo "PASS: test_requirements.sh"
