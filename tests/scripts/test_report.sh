#!/usr/bin/env sh
set -eu
TPL="skills/re-report/report-template.md"
fail() { echo "FAIL: $1" >&2; exit 1; }
[ -f "$TPL" ] || fail "report-template.md missing"
# the make_report.sh scaffolder is gone — the report is written by hand from the template
[ ! -f skills/re-report/make_report.sh ] || fail "make_report.sh should be deleted"
# required top-down structure (summary first, expert sections, IOCs + YARA)
for s in "Executive summary" "Key findings" "Approaches tried" \
         "Obfuscation & anti-analysis" "Crypto & config" "IOCs" "YARA" \
         "Dead ends" "Reproduction" "Index"; do
  grep -qi "$s" "$TPL" || fail "template missing section: $s"
done
# executive summary must be the FIRST section heading
first=$(grep -m1 '^## ' "$TPL")
printf '%s' "$first" | grep -qi "Executive summary" || fail "Executive summary must be first (got: $first)"
echo "PASS: test_report.sh"
