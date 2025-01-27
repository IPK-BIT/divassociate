process compute_relatedness_matrix {
    container 'quay.io/biocontainers/gemma:0.98.3--hb4ccc14_0'
    publishDir params.outdir+'/results', mode: 'copy'

    cpus 1
    memory { 20.GB * task.attempt } 
    errorStrategy { task.exitStatus == 140 ? 'retry' : 'terminate' } 
    maxRetries 3 

    input:
    path(bedFile)
    path(bimFile)
    path(famFile)

    output:
    path("${famFile.baseName}.cXX.txt")

    script:
    """
    gemma -bfile $bedFile.baseName -gk 1 -outdir . -o ${famFile.baseName}
    """
}

process perform_association_test {
    container 'quay.io/biocontainers/gemma:0.98.3--hb4ccc14_0'
    publishDir params.outdir+'/results', mode: 'copy'

    cpus 1
    memory { 20.GB * task.attempt } 
    errorStrategy { task.exitStatus == 140 ? 'retry' : 'terminate' } 
    maxRetries 3 

    input:
    path(bedFile)
    path(bimFile)
    path(famFile)
    // path(covarFile)
    path(relatMatrix)

    output:
    path("${famFile.baseName}.assoc.txt"), emit: assocFile

    script:
    """
    gemma -bfile $bedFile.baseName -k $relatMatrix -lmm 2 -n 1 -notsnp -outdir . -o ${famFile.baseName}
    """
}