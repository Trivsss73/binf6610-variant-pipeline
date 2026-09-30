#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs

ARRAY_ID=$(sbatch --parsable slurm/01_persample.sbatch)
echo "submitted per-sample array: $ARRAY_ID"

COHORT_ID=$(sbatch --parsable --dependency=afterok:${ARRAY_ID} --kill-on-invalid-dep=yes slurm/02_cohort.sbatch)
echo "submitted cohort job: $COHORT_ID (depends on $ARRAY_ID)"
