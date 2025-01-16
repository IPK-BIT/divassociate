include { compute_relatedness_matrix } from '../../modules/local/gemma'
include { perform_association_test } from '../../modules/local/gemma'

workflow PERFORM_ASSOCIATION_STUDY {
    take:
    bed
    bim
    fam
    // covar
    
    main:
    ch_relatMatrix = compute_relatedness_matrix(bed, bim, fam)

    perform_association_test(bed, bim, fam, ch_relatMatrix)

    emit:
    assoc = perform_association_test.out.assocFile
}