include { DIVASSOCIATE } from './workflows/divassociate'
include { PIPELINE_INITIALIZATION } from './subworkflows/local/utils_divassociate_pipeline'
include { PIPELINE_COMPLETION } from './subworkflows/local/utils_divassociate_pipeline'

workflow {
    main:
    PIPELINE_INITIALIZATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.vcf,
        params.phenotypes
    )

    DIVASSOCIATE (
        params.samples,
        params.vcf,
        params.phenotypes,
        params.covariates
    )

    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
    )
}