#!/bin/bash
#SBATCH --job-name=cohort
#SBATCH --output=logs/cohort_%j.out
#SBATCH --error=logs/cohort_%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --export=NONE

source /courses/BINF6610.202710/shared/env/binf6610/bin/activate
cd "${SLURM_SUBMIT_DIR}"
source slurm/conf/slurm.env

export THREADS="${SLURM_CPUS_PER_TASK}"
export TMPDIR="/tmp/${SLURM_JOB_ID}"
mkdir -p "${TMPDIR}"
trap 'rm -rf "${TMPDIR}"' EXIT

export REF INDEX REGIONS
bash run_pipeline.sh --samplesheet "${SAMPLESHEET}" --outdir "${OUTDIR}" --from merge --to publish
