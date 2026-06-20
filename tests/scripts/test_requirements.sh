#!/usr/bin/env sh
# Validates the requirements/ install artifacts: global pip in the container
# image, a stdlib venv on the host — no uv anywhere.
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }

# python-tools.txt lists the expected tools
[ -s requirements/python-tools.txt ] || fail "python-tools.txt missing/empty"
grep -qi 'z3'   requirements/python-tools.txt || fail "python-tools.txt missing z3"
grep -qi 'angr' requirements/python-tools.txt || fail "python-tools.txt missing angr"

# setup.sh: valid POSIX sh, uses a stdlib venv + the venv var, and NO uv
sh -n requirements/setup.sh || fail "setup.sh syntax error"
grep -q 'python3 -m venv' requirements/setup.sh || fail "setup.sh missing 'python3 -m venv'"
grep -q 'RE_HARNESS_VENV' requirements/setup.sh || fail "setup.sh missing RE_HARNESS_VENV"
! grep -qw 'uv' requirements/setup.sh || fail "setup.sh still references uv"

# Dockerfile: python trixie base, global pip, build-time import check, NO uv
grep -Eq '^FROM python:3\.12-slim-trixie' requirements/Dockerfile || fail "Dockerfile base not python:3.12-slim-trixie"
grep -q 'pip install' requirements/Dockerfile     || fail "Dockerfile missing 'pip install'"
grep -q 'python-tools.txt' requirements/Dockerfile || fail "Dockerfile missing python-tools.txt"
grep -q 'import angr' requirements/Dockerfile      || fail "Dockerfile missing build-time import check"
! grep -qw 'uv' requirements/Dockerfile || fail "Dockerfile still references uv"

# the harness convention resolves a stdlib venv's python
ROOT="$(mktemp -d)"; V="$ROOT/venv"
if python3 -m venv "$V" >/dev/null 2>&1 && [ -x "$V/bin/python" ]; then
  PY=$(RE_HARNESS_VENV="$V" sh -c 'V="${RE_HARNESS_VENV:-$HOME/.local/share/re-harness/venv}"; if [ -x "$V/bin/python" ]; then echo "$V/bin/python"; else echo python3; fi')
  [ "$PY" = "$V/bin/python" ] || fail "venv-python resolution did not pick the venv"
else
  echo "(python venv unavailable — skipped live venv check)"
fi
rm -rf "$ROOT"

echo "PASS: test_requirements.sh"
