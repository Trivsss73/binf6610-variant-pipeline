#!/bin/bash
set -euo pipefail

SHEET="$1"
SHEET_DIR=$(dirname "$SHEET")
problems=0

while IFS=, read -r id cond rep lt r1 r2 _rest; do
    # Resolve relative paths against the samplesheet's folder
    [[ "$r1" = /* ]] || r1="${SHEET_DIR}/${r1}"
    [[ -s "$r1" ]] || { echo "$id: R1 missing or empty: $r1" >&2; problems=$((problems + 1)); }

    if [[ "$lt" == "paired" ]]; then
        [[ "$r2" = /* ]] || r2="${SHEET_DIR}/${r2}"
        [[ -s "$r2" ]] || { echo "$id: declared paired but R2 missing: $r2" >&2; problems=$((problems + 1)); }
    fi

    if [[ -s "$r1" ]]; then
        gzip -t "$r1" 2>/dev/null || { echo "$id: R1 is not valid gzip" >&2; problems=$((problems + 1)); }
    fi
    if [[ "$lt" == "paired" && -s "${r2:-}" ]]; then
        gzip -t "$r2" 2>/dev/null || { echo "$id: R2 is not valid gzip" >&2; problems=$((problems + 1)); }
    fi
done < <(tail -n +2 "$SHEET")

if (( problems > 0 )); then
    echo "validation failed: $problems problem(s)" >&2
    exit 1
fi
echo "validation passed" >&2
