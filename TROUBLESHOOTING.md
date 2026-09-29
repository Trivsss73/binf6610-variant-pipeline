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
