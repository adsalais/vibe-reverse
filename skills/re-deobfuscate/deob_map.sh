#!/usr/bin/env sh
# deob_map.sh — scaffold the deobfuscation map: layers found, peel order, status.
# NEVER executes the target. Usage: deob_map.sh <out-dir>
set -eu
OUT="${1:?usage: deob_map.sh <out-dir>}"
D="$OUT/artifacts/deobfuscation"; mkdir -p "$D"
MAP="$D/map.md"
[ -f "$MAP" ] || cat > "$MAP" <<'EOF'
# Deobfuscation map

Peel the OUTERMOST layer first; re-triage between layers (packers nest; a peeled
payload may be a new binary — register it with add_binary.sh).

| # | layer / technique | handler / route | status | notes / artifact |
|---|-------------------|-----------------|--------|------------------|
| 1 | <e.g. UPX packing> | unpack.sh | todo | |
| 2 | <e.g. string/API obfuscation> | FLOSS / re-scripting | todo | |
| 3 | <e.g. control-flow flattening> | miasm/angr (re-scripting) | todo | |
| 4 | <e.g. opaque predicates> | z3 + patch (keystone/lief) | todo | |
| 5 | <e.g. virtualization> | re-devirtualize | todo | |

Done when: entropy is normal, strings/imports are readable, control flow is sane.
EOF
echo "$MAP"
