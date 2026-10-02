#!/bin/bash
#SBATCH -A binf6610.202710 -p courses
#SBATCH -c 4 --mem=16G -t 00:30:00
#SBATCH -o logs/pull-%j.out
set -euo pipefail
export APPTAINER_CACHEDIR=/scratch/${USER}/apptainer-cache
mkdir -p /scratch/${USER}/containers
apptainer pull /scratch/${USER}/containers/variant-call.sif \
    docker://trivsss73/variant-call@sha256:922edab15144c2dc8744bee301c13a3ac4348e04b2bd85e9e0956a45b8f231cf
