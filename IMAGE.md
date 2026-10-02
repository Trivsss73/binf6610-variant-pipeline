# Container Image

## Pushed image digest

`docker.io/trivsss73/variant-call@sha256:922edab15144c2dc8744bee301c13a3ac4348e04b2bd85e9e0956a45b8f231cf`

Pulled on Explorer with this digest to produce `/scratch/trivedi.dhai/containers/variant-call.sif` (1.2 GB).

## Base image

`mambaorg/micromamba:2.0.5-ubuntu24.04` — an Ubuntu 24.04 image with micromamba preinstalled, which allowed a single `RUN` layer to install everything from bioconda and conda-forge.

## Tool versions

Pinned in `containers/Dockerfile`, confirmed with `tests/print_versions.sh` run inside the image:

| Tool | Version |
|------|---------|
| bwa | 0.7.19 |
| samtools | 1.24 |
| bcftools | 1.24 |
| gatk4 | 4.6.2.0 |
| fastqc | 0.12.1 |
| fastp | 1.3.7 |
| multiqc | 1.35 |
| git | 2.47.0 |

All seven bioinformatics tools match the versions in `/courses/BINF6610.202710/shared/env/binf6610`. `diff versions-conda.txt versions-image.txt` prints nothing.
