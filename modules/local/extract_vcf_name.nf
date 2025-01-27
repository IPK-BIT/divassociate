process extract_prefix {
    container 'quay.io/biocontainers/ubuntu:22.04'
    
    cpus 1
    memory { 20.GB * task.attempt } 
    errorStrategy { task.exitStatus == 140 ? 'retry' : 'terminate' } 
    maxRetries 3 

    input:
    path vcf_file

    output:
    stdout

    script:
    """
    #!/bin/bash

    filename=\$(basename "$vcf_file")

    if [[ "$vcf_file" == *.gz ]]; then
        prefix="\${filename%.vcf.gz}"
    else
        prefix="\${filename%.vcf}"
    fi
    echo "\$prefix"
    """
}