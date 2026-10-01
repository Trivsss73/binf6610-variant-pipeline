#!/usr/bin/env bash
set -euo pipefail

# ---- arguments ----

if [[ "${1:-}" == --* ]]; then
    # flag style: --samplesheet X --outdir Y --to Z
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --samplesheet) SHEET="$2"; shift 2 ;;
            --outdir)      OUTDIR="$2"; shift 2 ;;
            --from)        LAST="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
else
    # positional style
    SHEET="${1:-}"
    OUTDIR="${2:-}"
    LAST="${3:-publish}"
fi

[[ -n "${SHEET:-}" ]] || { echo "Usage: $0 <samplesheet> <outdir> [--to stage]" >&2; exit 1; }
[[ -n "${OUTDIR:-}" ]] || { echo "Usage: $0 <samplesheet> <outdir> [--to stage]" >&2; exit 1; }
LAST="${LAST:-publish}"
FIRST="${FIRST:-validate}"

# ---- source config ----

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/conf/pipeline.env"

# ---- logging (always to stderr) ----
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { log "FATAL: $*"; exit 1; }

# ---- stage list ----
STAGES=(validate qc_raw trim align postprocess quantify merge analyze qc_report publish)

# ---- validate the --to argument ----
known=0
for stage in "${STAGES[@]}"; do
    [[ "$stage" == "$LAST" ]] && known=1
done
(( known )) || die "unknown stage: $LAST"

# ---- stage 0: validate ----
stage_validate() {
    local problems=0

    [[ -s "$SHEET" ]] || die "sample sheet missing or empty: $SHEET"

    local dupes
    dupes=$(tail -n +2 "$SHEET" | cut -d, -f1 | sort | uniq -d)
    if [[ -n "$dupes" ]]; then
        log "duplicate sample_id(s): $dupes"
        (( problems++ )) || true
    fi

    local id cond rep layout r1 r2
    while IFS=, read -r id cond rep layout r1 r2; do
        if [[ ! -s "$r1" ]]; then
            log "$id: R1 missing or empty: $r1"
            (( problems++ )) || true
        else
            if ! gzip -t "$r1" 2>/dev/null; then
                log "$id: R1 is truncated or corrupt: $r1"
                (( problems++ )) || true
            fi
        fi

        if [[ "$layout" == "paired" ]]; then
            if [[ -z "$r2" ]]; then
                log "$id: paired but r2_fastq is empty"
                (( problems++ )) || true
            elif [[ ! -s "$r2" ]]; then
                log "$id: R2 missing or empty: $r2"
                (( problems++ )) || true
            fi
        fi
    done < <(tail -n +2 "$SHEET")

    (( problems == 0 )) || die "validation failed: $problems problem(s)"
    log "validation passed: all samples OK"
}

# ---- stub stages ----

stage_qc_raw() {
 
mkdir -p "${OUTDIR}/qc_raw" "${OUTDIR}/logs"
    local id cond rep layout r1 r2

    while IFS=, read -r id cond rep layout r1 r2; do
        log "fastqc: $id R1"
        fastqc -q -o "${OUTDIR}/qc_raw" "$r1" 2>> "${OUTDIR}/logs/${id}.fastqc.log"

        if [[ "$layout" == "paired" ]]; then
            log "fastqc: $id R2"
            fastqc -q -o "${OUTDIR}/qc_raw" "$r2" 2>> "${OUTDIR}/logs/${id}.fastqc.log"
        fi

        local base
        base=$(basename "$r1" .fastq.gz)
        [[ -s "${OUTDIR}/qc_raw/${base}_fastqc.zip" ]] || die "$id: fastqc produced no report"
    done < <(tail -n +2 "$SHEET")

    log "qc_raw complete"

 }

stage_trim()  {

 mkdir -p "${OUTDIR}/trimmed"
    local id cond rep layout r1 r2

    while IFS=, read -r id cond rep layout r1 r2; do
        log "trimming: $id"

        if [[ "$layout" == "paired" ]]; then
            fastp \
                -i "$r1" -I "$r2" \
                -o "${OUTDIR}/trimmed/${id}_R1.fastq.gz" \
                -O "${OUTDIR}/trimmed/${id}_R2.fastq.gz" \
                --json "${OUTDIR}/trimmed/${id}.fastp.json" \
                --html "${OUTDIR}/trimmed/${id}.fastp.html" \
                2>> "${OUTDIR}/logs/${id}.fastp.log"
        else
            fastp \
                -i "$r1" \
                -o "${OUTDIR}/trimmed/${id}_R1.fastq.gz" \
                --json "${OUTDIR}/trimmed/${id}.fastp.json" \
                --html "${OUTDIR}/trimmed/${id}.fastp.html" \
                2>> "${OUTDIR}/logs/${id}.fastp.log"
        fi

        [[ -s "${OUTDIR}/trimmed/${id}_R1.fastq.gz" ]] || die "$id: trimming produced no output"
    done < <(tail -n +2 "$SHEET")

    log "trim complete"

 }
stage_align()        {

    mkdir -p "${OUTDIR}/aligned"
    local id cond rep layout r1 r2

    while IFS=, read -r id cond rep layout r1 r2; do
        log "aligning: $id"

        if [[ "$layout" == "paired" ]]; then
            bwa mem -t "$THREADS" -R  "@RG\tID:${id}\tSM:${id}\tLB:${id}\tPL:ILLUMINA" "$INDEX" \
                "${OUTDIR}/trimmed/${id}_R1.fastq.gz" \
                "${OUTDIR}/trimmed/${id}_R2.fastq.gz" \
                2> "${OUTDIR}/logs/${id}.bwa.log" \
                | samtools sort -@ 2 -o "${OUTDIR}/aligned/${id}.bam"
        else
            bwa mem -t "$THREADS" -R "@RG\tID:${id}\tSM:${id}\tLB:${id}\tPL:ILLUMINA" "$INDEX" \
                "${OUTDIR}/trimmed/${id}_R1.fastq.gz" \
                2> "${OUTDIR}/logs/${id}.bwa.log" \
                | samtools sort -@ 2 -o "${OUTDIR}/aligned/${id}.bam"
        fi

        [[ -s "${OUTDIR}/aligned/${id}.bam" ]] || die "$id: alignment produced no BAM"
    done < <(tail -n +2 "$SHEET")

    log "align complete"
}

stage_postprocess()  {

local id cond rep layout r1 r2

    while IFS=, read -r id cond rep layout r1 r2; do
        log "postprocessing: $id"

        local bam="${OUTDIR}/aligned/${id}.bam"

        # mark duplicates
        gatk MarkDuplicates \
            -I "$bam" \
            -O "${OUTDIR}/aligned/${id}.dedup.bam" \
            -M "${OUTDIR}/logs/${id}.dup_metrics.txt" \
            2>> "${OUTDIR}/logs/${id}.markdup.log"

        # index the deduped BAM
        samtools index "${OUTDIR}/aligned/${id}.dedup.bam"

        [[ -s "${OUTDIR}/aligned/${id}.dedup.bam" ]] || die "$id: mark duplicates failed"
    done < <(tail -n +2 "$SHEET")
    
    log "postprocess complete"

 }
stage_quantify()     {

    mkdir -p "${OUTDIR}/gvcf"
    local id cond rep layout r1 r2

    while IFS=, read -r id cond rep layout r1 r2; do
        log "calling variants: $id"

        gatk HaplotypeCaller \
            -R "$REF" \
            -I "${OUTDIR}/aligned/${id}.dedup.bam" \
            -O "${OUTDIR}/gvcf/${id}.g.vcf.gz" \
            -ERC GVCF \
            -L "$REGIONS" \
            2>> "${OUTDIR}/logs/${id}.haplotypecaller.log"

        [[ -s "${OUTDIR}/gvcf/${id}.g.vcf.gz" ]] || die "$id: HaplotypeCaller produced no GVCF"
    done < <(tail -n +2 "$SHEET")

    log "quantify complete"

 }
stage_merge()        {

    mkdir -p "${OUTDIR}/merged"
    log "joint genotyping across all samples"

    local gvcf_args=()
    local id cond rep layout r1 r2
    while IFS=, read -r id cond rep layout r1 r2; do
        gvcf_args+=(-V "${OUTDIR}/gvcf/${id}.g.vcf.gz")
    done < <(tail -n +2 "$SHEET")

    local ws="${TMPDIR:-/tmp}/genomicsdb"
    rm -rf "${ws}"

    gatk GenomicsDBImport \
        "${gvcf_args[@]}" \
        --genomicsdb-workspace-path "${ws}" \
        -L "$REGIONS" \
        2>> "${OUTDIR}/logs/genomicsdb.log"

    gatk GenotypeGVCFs \
        -R "$REF" \
        -V "gendb://${ws}" \
        -O "${OUTDIR}/merged/cohort.vcf.gz" \
        2>> "${OUTDIR}/logs/genotypegvcfs.log"

    [[ -s "${OUTDIR}/merged/cohort.vcf.gz" ]] || die "joint genotyping produced no VCF"
    log "merge complete"

 }
stage_analyze()      {

mkdir -p "${OUTDIR}/filtered"
    log "filtering variants"

    gatk VariantFiltration \
        -R "$REF" \
        -V "${OUTDIR}/merged/cohort.vcf.gz" \
        -O "${OUTDIR}/filtered/cohort.filtered.vcf.gz" \
        --filter-expression "QD < 2.0" --filter-name "LowQD" \
        --filter-expression "FS > 60.0" --filter-name "HighFS" \
        --filter-expression "MQ < 40.0" --filter-name "LowMQ" \
        2>> "${OUTDIR}/logs/filtration.log"

    [[ -s "${OUTDIR}/filtered/cohort.filtered.vcf.gz" ]] || die "variant filtration failed"
    log "analyze complete"

 }
stage_qc_report()    {

    mkdir -p "${OUTDIR}/qc_report"
    log "generating QC report"

    multiqc "$OUTDIR" -o "${OUTDIR}/qc_report" -f 2>> "${OUTDIR}/logs/multiqc.log"

    [[ -s "${OUTDIR}/qc_report/multiqc_report.html" ]] || die "MultiQC produced no report"
    log "qc_report complete"

 }
stage_publish()      {

    mkdir -p "${OUTDIR}/publish"
    log "publishing results"

    local sha
    sha=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        sha="${sha}-dirty"
    fi

        printf '{\n  "git_sha": "%s",\n  "date": "%s",\n  "samplesheet": "%s",\n  "reference": "%s",\n  "regions": "%s"\n}\n' \
        "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SHEET" "$REF" "$REGIONS" \
        > "${OUTDIR}/publish/manifest.json"

    log "manifest written: git_sha=$sha"
    log "publish complete"

 }

# ---- driver: run stages in order ----
running=false
for stage in "${STAGES[@]}"; do
    [[ "$stage" == "$FIRST" ]] && running=true
    [[ "$running" == true ]] || continue
    log "===== stage: $stage ====="
    "stage_${stage}"
    [[ "$stage" == "$LAST" ]] && break
done
