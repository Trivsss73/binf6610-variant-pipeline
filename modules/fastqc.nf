process FASTQC {
    tag "${meta.id}"
    container params.containers.fastqc

    input:
    tuple val(meta), path(reads)

    output:
    path '*_fastqc.zip', emit: zip

    script:
    """
    fastqc -q -t ${task.cpus} ${reads}
    """
}
