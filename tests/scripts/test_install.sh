#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT
# install.sh loads the image only if the tar is present; here it is not, so docker
# load is skipped and we exercise seeding + launcher install.
HOME="$H" sh deploy/install.sh >/dev/null 2>&1 || fail "install.sh failed"
[ -f "$H/.config/vibe-reverse/opencode.json" ] || fail "opencode.json not seeded"
[ -f "$H/.config/vibe-reverse/auth.json" ]     || fail "auth.json not seeded"
[ -x "$H/.local/bin/vibe-reverse" ]            || fail "launcher not installed"
# idempotent + no-clobber: a user edit survives a second run
echo "EDITED" > "$H/.config/vibe-reverse/opencode.json"
HOME="$H" sh deploy/install.sh >/dev/null 2>&1 || fail "second install failed"
grep -q EDITED "$H/.config/vibe-reverse/opencode.json" || fail "config was clobbered"
echo "PASS: test_install.sh"
