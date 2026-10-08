process BWA_MEM {
    tag "${meta.id}"
    container params.containers.bwa

    input:
    tuple val(meta), path(reads)
    path ref
    path ref_index

    output:
    tuple val(meta), path("${meta.id}.bam"), path("${meta.id}.bam.bai"), emit: bam

    script:
    """
    bwa mem -t ${task.cpus} -R "@RG\\tID:${meta.id}\\tSM:${meta.id}\\tLB:${meta.id}\\tPL:ILLUMINA" ${ref} ${reads} \
        2> ${meta.id}.bwa.log \
        | samtools sort -@ 2 -o ${meta.id}.bam
    samtools index ${meta.id}.bam
    """
}
