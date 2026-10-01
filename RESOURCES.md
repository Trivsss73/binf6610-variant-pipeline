# Resource Measurements

## Per-sample array tasks (8 cores, 8 GB, 2 hours)

seff output for task 1 (NA12878, paired):

    CPU Utilized: 00:20:13
    CPU Efficiency: 28.66% of 01:10:32 core-walltime
    Job Wall-clock time: 00:08:49
    Memory Utilized: 12.12 GB

seff output for task 3 (NA12892, single-end):

    CPU Utilized: 00:12:56
    CPU Efficiency: 26.15% of 00:49:28 core-walltime
    Job Wall-clock time: 00:06:11
    Memory Utilized: 11.39 GB

Cores busy: 20:13 / 8:49 = 2.3 cores for the paired sample, 12:56 / 6:11 = 2.1 for single-end. Eight cores reserved and about two were working. Only bwa mem uses multiple threads; the other stages are single-threaded.

Memory used 12 GB against an 8 GB request. Explorer does not enforce memory limits, so the jobs completed. On a cluster that does, they would be killed. Therefore I changed --mem to 16G.

## Cohort job (4 cores, 8 GB, then raised)

seff output:

    CPU Utilized: 02:57:45
    CPU Efficiency: 54.09% of 05:28:36 core-walltime
    Job Wall-clock time: 01:22:09
    Memory Utilized: 22.06 GB

The first submission timed out at 1 hour. Changed --time to 02:00:00 and --mem to 24G.

## What I changed

Per-sample: reduce --cpus-per-task to 4, raise --mem to 16G.
Cohort: raise --time to 02:00:00, --mem to 24G. Use TMPDIR for GenomicsDBImport workspace instead of /scratch.
