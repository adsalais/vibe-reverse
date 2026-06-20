#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
S=skills/re-config/references/ioc-schema.md
Y=skills/re-config/references/yara-template.yar
[ -f "$S" ] || fail "ioc-schema.md missing"
[ -f "$Y" ] || fail "yara-template.yar missing"
for k in c2 mutex key persistence campaign; do
  grep -qi "$k" "$S" || fail "ioc-schema missing field: $k"
done
grep -qi 'rule '      "$Y" || fail "yara-template has no rule"
grep -qi 'condition'  "$Y" || fail "yara-template missing condition"
echo "PASS: test_config.sh"
