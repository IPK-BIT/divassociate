include { CONTRIBUTION_TEST } from '../subworkflows/local/covariate_analysis'
include { PREPARE_INPUTS } from '../subworkflows/local/input_preparation'
include { PREPARE_OUTPUTS } from '../subworkflows/local/output_preparation'
include { PERFORM_ASSOCIATION_STUDY } from '../subworkflows/local/association_study'

include { extract_prefix } from '../modules/local/extract_vcf_name'


workflow DIVASSOCIATE {
    take:
    samples
    vcf
    phenotypes
    covariates

    main:
    ch_prefix = extract_prefix(Channel.fromPath(vcf))
    | map { it.trim() }

    CONTRIBUTION_TEST(phenotypes, covariates)

    PREPARE_INPUTS(phenotypes, covariates, vcf, samples, ch_prefix)

    PERFORM_ASSOCIATION_STUDY(PREPARE_INPUTS.out.bed, PREPARE_INPUTS.out.bim, PREPARE_INPUTS.out.fam, PREPARE_INPUTS.out.covar)

    PREPARE_OUTPUTS(PERFORM_ASSOCIATION_STUDY.out.assoc)
}