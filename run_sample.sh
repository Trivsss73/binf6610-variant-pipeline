#!/usr/bin/env bash
set -euo pipefail

# Usage: run_one_sample.sh <samplesheet> <outdir> <sample_id>
SHEET="${1:?Usage: $0 <samplesheet> <outdir> <sample_id>}"
OUTDIR="${2:?Usage: $0 <samplesheet> <outdir> <sample_id>}"
SAMPLE="${3:?Usage: $0 <samplesheet> <outdir> <sample_id>}"

# Refuse cohort stages — merge, analyze, qc_report, publish need every sample
# and a single task cannot know whether the others finished. That is the
# scheduler's job. run_sample.sh stops at quantify.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/conf/pipeline.env"

log() { printf '[%s] [%s] %s\n' "$(date +%H:%M:%S)" "$SAMPLE" "$*" >&2; }
die() { log "FATAL: $*"; exit 1; }

# Extract this sample's row
ROW=$(grep "^${SAMPLE}," "$SHEET")
[[ -n "$ROW" ]] || die "sample $SAMPLE not found in $SHEET"

IFS=, read -r id cond rep layout r1 r2 <<< "$ROW"

# ---- stage 0: validate this sample ----
log "validating"
[[ -s "$r1" ]] || die "R1 missing: $r1"
if [[ "$layout" == "paired" ]]; then
    [[ -n "$r2" && -s "$r2" ]] || die "paired but R2 missing: $r2"
fi
gzip -t "$r1" 2>/dev/null || die "R1 truncated: $r1"

# ---- stage 1: qc_raw ----
log "fastqc"
mkdir -p "${OUTDIR}/qc_raw" "${OUTDIR}/logs"
fastqc -q -o "${OUTDIR}/qc_raw" "$r1" 2>> "${OUTDIR}/logs/${id}.fastqc.log"
[[ "$layout" == "paired" ]] && fastqc -q -o "${OUTDIR}/qc_raw" "$r2" 2>> "${OUTDIR}/logs/${id}.fastqc.log"

# ---- stage 2: trim ----
log "trimming"
mkdir -p "${OUTDIR}/trimmed"
if [[ "$layout" == "paired" ]]; then
    fastp -i "$r1" -I "$r2" \
        -o "${OUTDIR}/trimmed/${id}_R1.fastq.gz" -O "${OUTDIR}/trimmed/${id}_R2.fastq.gz" \
        --json "${OUTDIR}/trimmed/${id}.fastp.json" --html "${OUTDIR}/trimmed/${id}.fastp.html" \
        2>> "${OUTDIR}/logs/${id}.fastp.log"
else
    fastp -i "$r1" \
        -o "${OUTDIR}/trimmed/${id}_R1.fastq.gz" \
        --json "${OUTDIR}/trimmed/${id}.fastp.json" --html "${OUTDIR}/trimmed/${id}.fastp.html" \
        2>> "${OUTDIR}/logs/${id}.fastp.log"
fi
[[ -s "${OUTDIR}/trimmed/${id}_R1.fastq.gz" ]] || die "trim produced no output"

# ---- stage 3: align ----
log "aligning"
mkdir -p "${OUTDIR}/aligned"
if [[ "$layout" == "paired" ]]; then
    bwa mem -t "$THREADS" -R "@RG\tID:${id}\tSM:${id}\tLB:${id}\tPL:ILLUMINA" "$INDEX" "${OUTDIR}/trimmed/${id}_R1.fastq.gz" "${OUTDIR}/trimmed/${id}_R2.fastq.gz" 2> "${OUTDIR}/logs/${id}.bwa.log" | samtools sort -@ 2 -o "${OUTDIR}/aligned/${id}.bam"
else
    bwa mem -t "$THREADS" -R "@RG\tID:${id}\tSM:${id}\tLB:${id}\tPL:ILLUMINA" "$INDEX" "${OUTDIR}/trimmed/${id}_R1.fastq.gz" 2> "${OUTDIR}/logs/${id}.bwa.log" | samtools sort -@ 2 -o "${OUTDIR}/aligned/${id}.bam"
fi
[[ -s "${OUTDIR}/aligned/${id}.bam" ]] || die "alignment produced no BAM"

# ---- stage 4: postprocess ----
log "marking duplicates"
gatk MarkDuplicates -I "${OUTDIR}/aligned/${id}.bam" -O "${OUTDIR}/aligned/${id}.dedup.bam" -M "${OUTDIR}/logs/${id}.dup_metrics.txt" 2>> "${OUTDIR}/logs/${id}.markdup.log"
samtools index "${OUTDIR}/aligned/${id}.dedup.bam"
[[ -s "${OUTDIR}/aligned/${id}.dedup.bam" ]] || die "mark duplicates failed"

# ---- stage 5: quantify ----
log "calling variants"
mkdir -p "${OUTDIR}/gvcf"
gatk HaplotypeCaller -R "$REF" -I "${OUTDIR}/aligned/${id}.dedup.bam" -O "${OUTDIR}/gvcf/${id}.g.vcf.gz" -ERC GVCF -L "$REGIONS" 2>> "${OUTDIR}/logs/${id}.haplotypecaller.log"
[[ -s "${OUTDIR}/gvcf/${id}.g.vcf.gz" ]] || die "HaplotypeCaller produced no GVCF"

log "done"
# This script refuses to run merge, analyze, qc_report, or publish.
# Those stages need the whole cohort and run_sample.sh stops at quantify.
# Requesting a cohort stage here is an error:
# die "run_sample.sh stops at quantify; cohort stages need run_pipeline.sh"
