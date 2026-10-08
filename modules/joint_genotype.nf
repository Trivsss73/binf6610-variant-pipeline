process JOINT_GENOTYPE {
    container params.containers.gatk

    input:
    path gvcfs
    path tbis
    path ref
    path ref_index
    path ref_dict
    val  region

    output:
    path 'cohort.vcf.gz',     emit: vcf
    path 'cohort.vcf.gz.tbi', emit: tbi

    script:
    def gvcf_args = gvcfs.collect { "-V ${it}" }.join(' ')
    """
    gatk GenomicsDBImport \
        ${gvcf_args} \
        --genomicsdb-workspace-path gendb \
        -L ${region}

    gatk GenotypeGVCFs \
        -R ${ref} \
        -V gendb://gendb \
        -O cohort.vcf.gz
    """
}
