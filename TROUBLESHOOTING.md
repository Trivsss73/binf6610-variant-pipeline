# TROUBLESHOOTING — Week 5

## Failure 1: Ctrl-C mid-run, then rerun

**Command:** Ran the smoke pipeline, pressed Ctrl-C during fastqc (smoke_02).

**What happened:** Snakemake printed `Terminating processes on user request` and exit status 130. On the next run without any flag, Snakemake raised `IncompleteFilesException` for `work/fastqc/smoke_02` and told me to rerun with `--rerun-incomplete`. With that flag, 17 of 17 jobs ran: the 4 jobs that had completed before the interrupt were reused.

**Fix:** Add `--rerun-incomplete` to the command. Snakemake knows which output files were cut off and reruns only those rules.

## Failure 2: log without {sample} wildcard

**Command:** Changed bwa_mem's log from `"logs/bwa_mem/{sample}.log"` to `"logs/bwa_mem.log"` and ran `snakemake -n`.

**What happened:** Snakemake refused to build the DAG: `Not all output, log and benchmark files of rule bwa_mem contain the same wildcards.` The output has `{sample}` but the log does not, and Snakemake requires them to match so that two jobs do not write to the same log file.

**Fix:** Every per-sample rule's log must include the same `{sample}` wildcard as its output.

## Failure 3: Removed wildcard_constraints from both fastp rules

**Command:** Deleted the `wildcard_constraints: sample=one_of(PAIRED)` and `sample=one_of(SINGLE)` from `fastp_paired` and `fastp_single`, then ran `snakemake -n`.

**What happened:** `AmbiguousRuleException`: rules `fastp_paired` and `fastp_single` are ambiguous for `work/trim/smoke_01_R1.trim.fastq.gz`. Both rules can produce the same output file for sample smoke_01, and Snakemake cannot choose between them.

**Fix:** Restore the `wildcard_constraints:` in each rule, so `fastp_paired` only matches paired samples and `fastp_single` only matches single-end samples.

## Failure 4: Removed software-deployment-method: apptainer on Explorer

**Command:** Deleted `software-deployment-method: apptainer` from `profiles/explorer/profile.yaml` and submitted the head job.

**What happened:** `fastp_paired` (NA12873) failed with exit status 127. The Slurm log at `.snakemake/slurm_logs/rule_fastp_paired/NA12873/11110865.log` showed `Singularity containers: ignored` and the rule's own log said `fastp: command not found`. Without Apptainer, Snakemake ran the rule on the bare compute node, which has no bioinformatics tools installed.

**Fix:** Put `software-deployment-method: apptainer` back in the explorer profile. On resubmission, validate did not rerun because its output file still existed from the first run.
