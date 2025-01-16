process extract_prefix {
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