process view_vcf {
    input:
    path vcf

    output:
    stdout

    script:
    """
    bcftools view ${vcf}
    """
}

process slice_vcf {
    container 'quay.io/biocontainers/bcftools:1.18--h8b25389_0'
    
    input:
    path(vcfFile)
    path(sampleFile)

    output:
    path("${vcfFile.baseName}.vcf.gz")

    script:
    """
    bcftools view -Oz -o ${vcfFile.baseName}.vcf.gz -S $sampleFile $vcfFile
    """
}