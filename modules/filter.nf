process FILTER {
    container params.containers.gatk

    input:
    path vcf
    path vcf_tbi
    path ref
    path ref_index
    path ref_dict
    val  region

    output:
    path 'cohort.filtered.vcf.gz',     emit: vcf
    path 'cohort.filtered.vcf.gz.tbi', emit: tbi
    path 'variants.tsv',               emit: table

    script:
    """
    gatk VariantFiltration \
        -R ${ref} \
        -V ${vcf} \
        -O cohort.filtered.vcf.gz \
        --filter-expression "QD < 2.0" --filter-name "LowQD" \
        --filter-expression "FS > 60.0" --filter-name "HighFS" \
        --filter-expression "MQ < 40.0" --filter-name "LowMQ"

    printf 'chrom\\tpos\\tref\\talt\\tqual\\tfilter\\n' > variants.tsv
    bcftools query -f '%CHROM\\t%POS\\t%REF\\t%ALT\\t%QUAL\\t%FILTER\\n' cohort.filtered.vcf.gz >> variants.tsv
    """
}
