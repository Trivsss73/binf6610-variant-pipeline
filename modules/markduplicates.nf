process MARKDUPLICATES {
    tag "${meta.id}"
    container params.containers.gatk

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${meta.id}.dedup.bam"), path("${meta.id}.dedup.bam.bai"), emit: bam

    script:
    """
    gatk MarkDuplicates \
        -I ${bam} \
        -O ${meta.id}.dedup.bam \
        -M ${meta.id}.dup_metrics.txt
    samtools index ${meta.id}.dedup.bam
    """
}
