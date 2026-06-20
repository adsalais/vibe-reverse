#!/usr/bin/env sh
# Static checks on the deploy/ image build artifacts (no docker required).
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
D=deploy/Dockerfile

# base image is the python trixie image
grep -Eq '^FROM python:3\.12-slim-trixie' "$D" || fail "Dockerfile base is not python:3.12-slim-trixie"
# Java from apt (full JDK 21), not a staged Temurin tarball
grep -q 'openjdk-21-jdk' "$D" || fail "Dockerfile does not apt-install openjdk-21-jdk"
! grep -qi 'temurin' "$D" || fail "Dockerfile still references Temurin"
! grep -q  'jdk21'   "$D" || fail "Dockerfile still references staged jdk21"
# python installed globally, no uv / no venv, verified by an import
grep -q 'pip install' "$D" || fail "Dockerfile missing global pip install"
! grep -qw 'uv' "$D" || fail "Dockerfile still references uv"
grep -q 'import angr' "$D" || fail "Dockerfile missing build-time import check"
# the baked vibe user; no world-writable passwd hack
grep -q 'useradd' "$D" || fail "Dockerfile does not create the vibe user"
! grep -q '0666 /etc/passwd' "$D" || fail "Dockerfile still chmods /etc/passwd world-writable"
# privilege-drop + identity tooling installed
grep -q 'setpriv\|util-linux' "$D" || fail "Dockerfile does not ensure setpriv/util-linux"

# build.sh no longer passes Temurin build args
! grep -qi 'temurin' deploy/build.sh || fail "build.sh still references Temurin"

# entrypoint: starts root, remaps vibe, drops via setpriv; ensure-user.sh is gone
E=deploy/entrypoint.sh
sh -n "$E" || fail "entrypoint.sh syntax error"
grep -q 'setpriv'  "$E" || fail "entrypoint.sh does not drop privileges via setpriv"
grep -q 'usermod'  "$E" || fail "entrypoint.sh does not remap the vibe uid"
grep -q 'HOST_UID' "$E" || fail "entrypoint.sh does not read HOST_UID"
[ ! -e deploy/ensure-user.sh ] || fail "deploy/ensure-user.sh should be deleted"
! grep -rq 'ensure-user' deploy/entrypoint.sh deploy/smoke.sh || fail "ensure-user still referenced"

# smoke: global python import (no venv path), checks vibe user + setpriv
S=deploy/smoke.sh
sh -n "$S" || fail "smoke.sh syntax error"
grep -q 'python3 -c' "$S"     || fail "smoke.sh not using global python3"
grep -q 'import z3, angr' "$S" || fail "smoke.sh missing angr/z3 import"
! grep -q '/opt/vibe-reverse/venv' "$S" || fail "smoke.sh still references the venv path"

echo "PASS: test_deploy_image.sh"
