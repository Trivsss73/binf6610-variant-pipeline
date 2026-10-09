# TROUBLESHOOTING — Week 4

## Failure 1: `-resume` after Ctrl-C

**Command:** Ran the smoke pipeline, pressed Ctrl-C during FASTP/BWA_MEM, then reran with `-resume`.

**What happened:** The interrupted run killed 6 running tasks. On resume, VALIDATE (1 task) and FASTP (2 tasks) showed `cached` because they had finished before the interrupt. The other 17 tasks ran again. Nextflow reported `Cached: 3`.

**Fix:** `-resume` is the fix. It reuses every task that completed successfully and reruns the rest.

## Failure 2: Reference as a queue channel

**Command:** Changed `BWA_MEM(FASTP.out.reads, ref, ref_index)` to `BWA_MEM(FASTP.out.reads, channel.fromPath(params.ref), ref_index)` and ran the smoke dataset.

**What happened:** BWA_MEM ran 1 of 1 instead of 3 of 3. Only one sample (smoke_02) made it through alignment and the rest of the pipeline. No error was reported. A queue channel is consumed after one sample reads it, so the other two samples had no reference and were silently dropped.

**Fix:** Use `file(params.ref)` to create a value channel, which can be read by every sample.

## Failure 3: Missing backslash on `\$(…)` in a script block

**Command:** Changed `LOCAL_DB=\$(mktemp -d)` to `LOCAL_DB=$(mktemp -d)` in `modules/joint_genotype.nf` and ran the smoke dataset.

**What happened:** JOINT_GENOTYPE failed with exit status 2. The task's `.command.sh` showed: LOCAL_DB=-V smoke_03.g.vcf.gz -V smoke_02.g.vcf.gz -V smoke_01.g.vcf.gzmktemp -d)
Nextflow interpreted `$(mktemp -d)` as a Groovy/Nextflow variable expansion instead of passing it to bash. The `.command.err` said: `syntax error near unexpected token ')'`.

**Fix:** Escape the dollar sign as `\$(mktemp -d)` so Nextflow passes it through to bash.

## Failure 4: Time limit too short on Explorer

**Command:** Set `time = '2m'` for the `BWA_MEM|HAPLOTYPECALLER` block in `nextflow.config` and submitted the Explorer run.

**What happened:** BWA_MEM (NA07357) failed with exit status 140. I aimed for HAPLOTYPECALLER to fail, but BWA_MEM and HAPLOTYPECALLER share the same `withName` block so both got the 2-minute limit, and BWA_MEM hit it first. `sacct` showed:10928267 nf-BWA_ME+ FAILED 00:01:21 00:02:00 12:0
The State was FAILED with Timelimit 00:02:00 and ExitCode 12:0. Nextflow translates the SIGTERM (signal 12 from Slurm's warning) into exit status 140.

**Fix:** Set `time = '1h'` back and resubmit with `-resume`. The cached tasks from before the failure were reused.
