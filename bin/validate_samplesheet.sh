#!/bin/bash
set -euo pipefail

SHEET="$1"
problems=0

while IFS=, read -r id cond rep lt r1 r2; do
    r1_base=$(basename "$r1")
    [[ -s "$r1_base" ]] || { echo "$id: R1 missing or empty: $r1_base" >&2; problems=$((problems + 1)); }

    if [[ "$lt" == "paired" ]]; then
        r2_base=$(basename "$r2")
        [[ -s "$r2_base" ]] || { echo "$id: declared paired but R2 missing: $r2_base" >&2; problems=$((problems + 1)); }
    fi

    if [[ -s "$r1_base" ]]; then
        gzip -t "$r1_base" 2>/dev/null || { echo "$id: R1 is not valid gzip" >&2; problems=$((problems + 1)); }
    fi
    if [[ "$lt" == "paired" && -s "${r2_base:-}" ]]; then
        gzip -t "$r2_base" 2>/dev/null || { echo "$id: R2 is not valid gzip" >&2; problems=$((problems + 1)); }
    fi
done < <(tail -n +2 "$SHEET")

if (( problems > 0 )); then
    echo "validation failed: $problems problem(s)" >&2
    exit 1
fi
echo "validation passed" >&2
