include { slice_vcf } from '../../modules/local/bcftools'
include { transform_VCF } from '../../modules/local/plink'

process correct_phenotypes {
    container 'quay.io/biocontainers/mulled-v2-d0aaa59a9c102cbb5fb1b38822949827c5119e45:a53fc5f5fda400a196436eac5c44ff3e2d42b0dc-0'
    publishDir params.outdir+"/results/fitting", mode: params.publish_dir_mode

    cpus 1
    memory { 5.GB * task.attempt } 
    errorStrategy { task.exitStatus == 140 ? 'retry' : 'terminate' } 
    maxRetries 3 

    input:
    path(phenotypes)
    path(covariates)

    output:
    path("corrected_phenotypes.tsv"), emit: phenotypesFile
    path("*_fit_summary.txt"), emit: fitSummary
    path("*_residuals.png"), emit: residualsPlot

    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import matplotlib.pyplot as plt
    import seaborn as sns
    from statsmodels.formula.api import ols

    pheno = pd.read_csv('$phenotypes', sep='\t')
    covar = pd.read_csv('$covariates', sep='\t')

    for col in covar.columns:
        if col != 'SAMPLE':
            if covar[col].dtype == 'object':
                covar[col] = pd.Categorical(covar[col]).codes -1

    data = pd.merge(pheno, covar, on='SAMPLE')

    export_cols = ['SAMPLE']
    for var in [col for col in pheno.columns if col != 'SAMPLE']:
        covars = ' + '.join([col for col in covar.columns if col != 'SAMPLE'])
        formula = f'{var} ~ {covars}'

        fit = ols(formula, data).fit()
        residuals = fit.resid

        df = pd.DataFrame({'resid': residuals})

        plt.figure(figsize=(10, 6))
        sns.displot(df['resid'], kde=True, bins=30, color='darkblue')

        plt.title('Distribution of Residuals', fontsize=16)
        plt.xlabel('Residual Values', fontsize=12)
        plt.ylabel('Frequency', fontsize=12)

        plt.tight_layout()
        plt.savefig(var+'_residuals.png')

        with open(var+'_fit_summary.txt', 'w') as f:
            f.write(fit.summary().as_text())
            
        pheno[var+'_residuals'] = residuals

        mean = pheno[var+'_residuals'].mean()

        pheno[var+'_residuals'] = pheno[var+'_residuals'].fillna(mean)
        export_cols.append(var+'_residuals')

    pheno[export_cols].to_csv('corrected_phenotypes.tsv', sep='\t', index=False)
    """
}

process transform_phenotypes {
    container 'quay.io/biocontainers/ubuntu:22.04'
        
    cpus 1
    memory { 5.GB * task.attempt } 
    errorStrategy { task.exitStatus == 140 ? 'retry' : 'terminate' } 
    maxRetries 3 

    input:
    path(phenotypes)

    output:
    path("phenotypes.txt"), emit: phenotypesFile

    script:
    """
    tail -n +2 $phenotypes > phenotypes_no_header.txt
    cut -d'\t' -f2,3 phenotypes_no_header.txt > phenotypes.txt
    """
}

process combine_with_pheno {
    container 'quay.io/biocontainers/ubuntu:22.04'
        
    cpus 1
    memory { 5.GB * task.attempt } 
    errorStrategy { task.exitStatus == 140 ? 'retry' : 'terminate' } 
    maxRetries 3 

    input:
    path(phenoFile)
    path(famFile)

    output:
    path("${famFile.baseName.replaceAll('_modified', '')}.fam")

    script:
    """
    paste -d ' ' $famFile $phenoFile > tmp.fam
    mv tmp.fam ${famFile.baseName.replaceAll('_modified', '')}.fam
    """
}

workflow PREPARE_INPUTS {
    take:
    phenotypes
    covariates
    vcf
    samples
    prefix

    main:
    ch_vcf = slice_vcf(Channel.fromPath(vcf), Channel.fromPath(samples))
    
    transform_VCF(ch_vcf, prefix)

    if (covariates != null) {
        correct_phenotypes(Channel.fromPath(phenotypes), Channel.fromPath(covariates))
        transform_phenotypes(correct_phenotypes.out.phenotypesFile)
    } else {
        transform_phenotypes(Channel.fromPath(phenotypes))
    }

    ch_fam = combine_with_pheno(transform_phenotypes.out.phenotypesFile, transform_VCF.out.famFile)
    
    emit:
    bim = transform_VCF.out.bimFile
    bed = transform_VCF.out.bedFile
    fam = ch_fam
    // covar = transform_phenotypes.out.covariatesFile
}