process HAPLOTYPECALLER {
    tag "${meta.id}"
    container params.containers.gatk

    input:
    tuple val(meta), path(bam), path(bai)
    path ref
    path ref_index
    path ref_dict
    val  region

    output:
    path "${meta.id}.g.vcf.gz",     emit: gvcf
    path "${meta.id}.g.vcf.gz.tbi", emit: tbi

    script:
    """
    gatk HaplotypeCaller \
        -R ${ref} \
        -I ${bam} \
        -O ${meta.id}.g.vcf.gz \
        -ERC GVCF \
        -L ${region} \
        --native-pair-hmm-threads ${task.cpus}
    """
}
