process transform_VCF {
    container 'quay.io/biocontainers/plink:1.90b6.21--hec16e2b_4'

    input:
    path(vcfFile)
    val(prefix)
    
    output:
    path("${prefix}.bed"), emit: bedFile
    path("${prefix}.bim"), emit: bimFile
    path("${prefix}_modified.fam"), emit: famFile

    script:
    """
    plink --allow-extra-chr --keep-allele-order --vcf ${vcfFile} --make-bed --out ${prefix} --double-id
    cut -d' ' -f1,2,3,4,5 ${prefix}.fam > ${prefix}_modified.fam
    """
}