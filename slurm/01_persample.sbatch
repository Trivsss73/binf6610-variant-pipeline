#!/bin/bash
#SBATCH --job-name=persample
#SBATCH --output=logs/persample_%A_%a.out
#SBATCH --error=logs/persample_%A_%a.err
#SBATCH --array=1-8
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --export=NONE

cd "${SLURM_SUBMIT_DIR}"
source slurm/conf/slurm.env

export THREADS="${SLURM_CPUS_PER_TASK}"
export TMPDIR="/tmp/${SLURM_JOB_ID}"
mkdir -p "${TMPDIR}"
trap 'rm -rf "${TMPDIR}"' EXIT

mkdir -p logs "${OUTDIR}"

SAMPLE=$(awk -F',' -v n="${SLURM_ARRAY_TASK_ID}" 'NR == n + 1 { print $1 }' "${SAMPLESHEET}")

if [[ -z "$SAMPLE" ]]; then
    echo "ERROR: no row ${SLURM_ARRAY_TASK_ID} in ${SAMPLESHEET}" >&2
    exit 1
fi

apptainer exec --cleanenv \
    --env THREADS="${THREADS}" \
    --env TMPDIR="${TMPDIR}" \
    --env SLURM_JOB_ID="${SLURM_JOB_ID}" \
    --env SLURM_CPUS_PER_TASK="${SLURM_CPUS_PER_TASK}" \
    --bind /courses/BINF6610.202710,/scratch/${USER} \
    "${SIF}" \
    bash run_sample.sh "${SAMPLESHEET}" "${OUTDIR}" "${SAMPLE}"
