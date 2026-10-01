#!/bin/bash
#SBATCH --job-name=persample
#SBATCH --output=logs/persample_%A_%a.out
#SBATCH --error=logs/persample_%A_%a.err
#SBATCH --array=1-8
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --export=NONE

module load miniconda3/25.9.1
source activate /courses/BINF6610.202710/shared/env/binf6610
export REF INDEX REGIONS THREADS
cd "${SLURM_SUBMIT_DIR}"
source slurm/conf/slurm.env

export THREADS="${SLURM_CPUS_PER_TASK}"
export TMPDIR="/tmp/${SLURM_JOB_ID}"
mkdir -p "${TMPDIR}"
trap 'rm -rf "${TMPDIR}"' EXIT

mkdir -p logs "${OUTDIR}"

# Get sample from samplesheet row
SAMPLE=$(awk -F',' -v n="${SLURM_ARRAY_TASK_ID}" 'NR == n + 1 { print $1 }' "${SAMPLESHEET}")

# Guard: refuse if row doesn't exist
if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: no row ${SLURM_ARRAY_TASK_ID} in ${SAMPLESHEET}" >&2
    exit 1
fi

bash run_sample.sh "${SAMPLESHEET}" "${OUTDIR}" "${SAMPLE}"
