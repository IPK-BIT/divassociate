process view_vcf {
    container 'quay.io/biocontainers/bcftools:1.18--h8b25389_0'
    
    cpus 1
    memory { 20.GB * task.attempt } 
    errorStrategy { task.exitStatus == 140 ? 'retry' : 'terminate' } 
    maxRetries 3 

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
    
    cpus 1
    memory { 20.GB * task.attempt } 
    errorStrategy { task.exitStatus == 140 ? 'retry' : 'terminate' } 
    maxRetries 3 
    
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