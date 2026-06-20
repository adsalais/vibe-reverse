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

echo "PASS: test_deploy_image.sh"
