# Troubleshooting Log

## Issue 1: set -e killed stage 0 at the first problem

Symptom: Ran validate against a samplesheet with three broken samples. Only the first problem was reported, then the script exited silently.

Evidence: Added bash -x tracing and saw the exit happened on (( problems++ )) when problems was 0. The arithmetic expression 0++ evaluates to 0, and set -e treats exit code 1 as a failure.

Cause: (( expression )) returns exit code 1 when the expression evaluates to 0. With set -e active, incrementing from 0 kills the script before it can collect the remaining problems.

Fix: Changed every (( problems++ )) to (( problems++ )) || true so the zero return does not trigger set -e. All four problems now reported together before exiting.

## Issue 2: GATK MarkDuplicates NullPointerException

Symptom: Stage 4 died on the first sample with exit code 3. No output, just a silent stop.

Evidence: Checked out/logs/NA12878.markdup.log and found a Java NullPointerException: SAMRecord.getReadGroup() returned null. Ran samtools view -H out/aligned/NA12878.bam and confirmed no @RG header line was present.

Cause: bwa mem in stage 3 had no -R flag, so no read group information was written into the SAM output. GATK requires every read to belong to a read group.

Fix: Added -R "@RG\tID:${id}\tSM:${id}\tLB:${id}\tPL:ILLUMINA" to both paired and single bwa mem calls. Reran from stage 3 and MarkDuplicates completed successfully.

## Issue 3: bwa mem -R flag broken by line continuation

Symptom: After adding -R, bwa reported "the read group line is not started with @RG", then on retry "option requires an argument -- R".

Evidence: The error changed depending on how the line was split in nano. Leading whitespace from the continuation line was prepended to @RG.

Cause: Bash line continuations with backslash include leading whitespace from the next line in the argument. Splitting -R from its value produced malformed input.

Fix: Placed -R and its "@RG" argument on the same unbroken line.


## Week 2: Four Deliberate Failures

### 1. TIMEOUT on the cohort job

sacct: 10721566 TIMEOUT 01:00:21

The cohort job re-ran all stages from stage 0 instead of just stages 6-9. It completed merge at about 1h22m but the 1-hour limit killed it before reaching analyze. The state was TIMEOUT, not FAILED. The log ended with "merge complete" and no error from the pipeline. Increased --time to 02:00:00.

### 2. All tasks FAILED, cohort CANCELLED under afterok

sacct: 10717313_1 FAILED 127:0
sacct: 10717314   CANCELLED Reason=Dependency

All 8 tasks failed with exit code 127 (command not found) because the conda activation path was wrong. The cohort job was CANCELLED with Reason=Dependency within seconds. This is afterok working correctly: no task succeeded, so the dependency could never be satisfied. Fixed by using module load miniconda3 then source activate.

### 3. Out-of-range array task

The guard in 01_persample.sbatch checks for an empty SAMPLE:

    [[ -n "${SAMPLE}" ]] || { echo "no row" >&2; exit 1; }

With --array=1-9 against eight rows, task 9 gets an empty sample name. Without the guard, the pipeline would run every stage over nothing, succeed at each, and exit 0. Nine COMPLETED tasks, eight results, nothing saying so.

### 4. Partial output from a timeout

The TIMEOUT cohort job (10721566) stopped after merge. cluster-out/merged/cohort.vcf.gz was 4.5 MB and intact. cluster-out/filtered/ was empty because analyze never ran. The rerun on an interactive node ran VariantFiltration on the existing VCF successfully. The pipeline was not fooled because the missing output directory made it clear the stage had never started.
